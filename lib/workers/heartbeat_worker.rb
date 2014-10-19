require 'net/http'
require 'faraday'
require 'mini_magick'
require 'faraday/digestauth'
require 'dalli'

module Evercam
  class HeartbeatWorker

    include Sidekiq::Worker
    sidekiq_options retry: false

    TIMEOUT = 5

    def self.run
      Camera.select(:exid).each do |r|
        perform_async(r[:exid])
      end
    end

    def snap_request(camera, updates, instant)
      begin
        conn = Faraday.new(:url => camera.external_url) do |faraday|
          faraday.request :basic_auth, camera.cam_username, camera.cam_password
          faraday.request :digest, camera.cam_username, camera.cam_password
          faraday.adapter Faraday.default_adapter  # make requests with Net::HTTP, because curl crashes on Heroku
          faraday.options.timeout = 5           # open/read timeout in seconds
          faraday.options.open_timeout = 2      # connection open timeout in seconds
        end
        response = conn.get do |req|
          req.url camera.res_url('jpg')
        end
        if response.status == 200
          if response.headers.fetch('content-type', '').start_with?('image')
            image = MiniMagick::Image.read(response.body)
            image.resize "300x300"
            updates.merge!(is_online: true, last_online_at: instant, preview: image.to_blob)
          else
            logger.warn("Camera seems online, but returned content type: #{response.headers.fetch('Content-Type', '')}")
          end
        end
      rescue URI::InvalidURIError
        raise BadRequestError, 'Invalid URL'
      rescue Net::OpenTimeout
        # offline
      rescue Faraday::TimeoutError
        # offline
      rescue Faraday::ConnectionFailed
        # offline
      rescue => e
        # we weren't expecting this (famous last words)
        logger.error(e.message)
        logger.error(e.class)
        logger.error(e.backtrace.inspect)
      end
      updates
    end

    def perform(camera_name)
      # Dalli cache
      options = { :namespace => "app_v1", :compress => true }
      if ENV["MEMCACHEDCLOUD_SERVERS"]
        @dc = Dalli::Client.new(ENV["MEMCACHEDCLOUD_SERVERS"].split(','), :username => ENV["MEMCACHEDCLOUD_USERNAME"], :password => ENV["MEMCACHEDCLOUD_PASSWORD"])
      else
        @dc = Dalli::Client.new('127.0.0.1:11211', options)
      end
      logger.info("Started update for camera #{camera_name}")
      instant = Time.now
      camera = Camera.by_exid(camera_name)
      return if camera.nil?
      updates = { is_online: false, last_polled_at: instant }

      unless camera.external_url.nil?
        updates = snap_request(camera, updates, instant)
      end
      begin
        if camera.is_online and not updates[:is_online]
          # Try one more time, some cameras are dumb
          updates = snap_request(camera, updates, instant)
          unless updates[:is_online]
            CameraActivity.create(
              camera: camera,
              access_token: nil,
              action: 'offline',
              done_at: Time.now,
              ip: nil
            )
          end
        end
        if not camera.is_online and updates[:is_online]
          CameraActivity.create(
            camera: camera,
            access_token: nil,
            action: 'online',
            done_at: Time.now,
            ip: nil
          )
        end
        trigger_webhook(camera)
        camera.update(updates)
        invalidate_for_user(camera.owner.username)
        invalidate_for_camera(camera)
        @dc.set(camera_name, camera, 0)
      rescue => e
        # we weren't expecting this (famous last words)
        logger.warn(e.message)
        logger.warn(e.backtrace.inspect)
      end
      logger.info("Update for camera #{camera.exid} finished. New status #{updates[:is_online]}")
    end

    def trigger_webhook(camera)
      webhooks = Webhook.where(camera_id: camera.id).all
      return if webhooks.empty?
      
      webhooks.each do |webhook|
        hook_conn = Faraday.new(:url => webhook.url) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 5
          faraday.options.open_timeout = 2
        end

        parameters = {
          id: camera.exid,
          last_polled_at: camera.last_polled_at,
          last_online_at: camera.last_online_at,
          is_online: camera.is_online
        }

        hook_conn.post '', parameters.to_s
      end 
    end

    #TODO: remove this and call CacheHelper methods directly
    def invalidate_for_user(username)
      ['true', 'false', ''].repeated_permutation(2) do |a|
        @dc.delete("user/cameras/#{username}/#{a[0]}/#{a[1]}")
      end
    end

    def invalidate_for_camera(camera)
      camera_sharees = CameraShare.where(camera_id: camera.id)
      unless camera_sharees.blank?
        camera_sharees.each do |user|
          username = User[user.user_id].username
          invalidate_for_user(username)
        end
      end
    end

  end
end

