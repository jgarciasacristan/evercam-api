require 'net/http'
require 'faraday'
require 'mini_magick'
require 'faraday/digestauth'

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

    def perform(camera_name)
      logger.info("Started update for camera #{camera_name}")
      instant = Time.now
      camera = Camera.by_exid(camera_name)
      return if camera.nil?
      updates = { is_online: false, last_polled_at: instant }

      unless camera.external_url.nil?
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

      end
      begin
        if camera.is_online and not updates[:is_online]
          CameraActivity.create(
            camera: camera,
            access_token: nil,
            action: 'offline',
            done_at: Time.now,
            ip: nil
          )
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
        camera.update(updates)
      rescue => e
        # we weren't expecting this (famous last words)
        logger.warn(e.message)
        logger.warn(e.backtrace.inspect)
      end
      logger.info("Update for camera #{camera.exid} finished. New status #{updates[:is_online]}")
    end

  end
end
