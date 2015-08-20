require 'stringio'

module Evercam
  module Actors
    class CameraUpdate < Mutations::Command

      required do
        string :id
      end

      optional do
        string :timezone
        string :name
        string :mac_address, :empty => true
        string :model, :empty => true
        string :vendor, :empty => true

        string :jpg_url, :empty => true
        string :mjpg_url, :empty => true
        string :h264_url, :empty => true
        string :audio_url, :empty => true
        string :mpeg_url, :empty => true
        string :external_host, :empty => true
        string :internal_host, :empty => true
        string :external_http_port, :empty => true
        string :internal_http_port, :empty => true
        string :external_rtsp_port, :empty => true
        string :internal_rtsp_port, :empty => true

        string :username
        boolean :is_public
        boolean :is_online

        string :cam_username, :empty => true
        string :cam_password, :empty => true

        string :location_lng, :empty => true
        string :location_lat, :empty => true

        boolean :discoverable

        integer :motiondetection_threshold
        string :schedule
        string :webhook_url
        string :region_of_interest
      end

      def validate
        if username && nil == User.by_login(username)
          add_error(:username, :exists, 'Username does not exist')
        end

        unless Camera.by_exid(id)
          add_error(:camera, :exists, 'Camera does not exist')
        end

        if name and name.length > 25
          add_error(:name, :valid, 'Camera Name is too long. Maximum 24 characters.')
        end

        if external_host && !external_host.blank? && !(external_host =~ Evercam::VALID_IP_ADDRESS_REGEX or external_host =~ Evercam::VALID_HOSTNAME_REGEX)
          add_error(:external_host, :valid, 'External host is invalid')
        end

        if internal_host && !internal_host.blank? && !(internal_host =~ Evercam::VALID_IP_ADDRESS_REGEX or internal_host =~ Evercam::VALID_HOSTNAME_REGEX)
          add_error(:internal_host, :valid, 'Internal host is invalid')
        end

        if timezone && false == Timezone::Zone.names.include?(timezone)
          add_error(:timezone, :valid, 'Timezone does not exist or is invalid')
        end

        if !vendor.blank? && Vendor.by_exid(vendor).first.nil?
          add_error(:vendor, :exists, 'Vendor does not exist')
        end

        if !model.blank? && vendor.blank?
          add_error(:model, :valid, 'If you provide model you must also provide vendor')
        end

        if !model.blank? && !vendor.blank? && !Vendor.find(:exid => vendor).nil? && !VendorModel.find(:exid => model, :vendor_id => Vendor.find(:exid => vendor).id)
          add_error(:model, :exists, 'Model does not exist')
        end

        if !mac_address.blank? && !(mac_address =~ /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/)
          add_error(:mac_address, :valid, 'Mac address is invalid')
        end

        if location_lng && nil == location_lat
          add_error(:location_lat, :valid, 'Must provide both location coordinates')
        end

        if location_lat && nil == location_lng
          add_error(:location_lng, :valid, 'Must provide both location coordinates')
        end

        if motiondetection_threshold && ( motiondetection_threshold < 1 || motiondetection_threshold > 100 )
          add_error(:motiondetection_threshold, :valid, 'Must provide motiondetection_threshold in between 1..100')
        end
        # TODO: add validation for
        # string :schedule
        # string :webhook_url
        # string :region_of_interest
      end

      def execute
        camera = ::Camera.by_exid(inputs[:id])

        [:external_http_port, :internal_http_port, :external_rtsp_port, :internal_rtsp_port].each do |port|
          unless inputs[port].nil?
            begin
              camera.values[:config].merge!({"#{port}" => inputs[port].empty? ? '' : Integer(inputs[port])})
            rescue ArgumentError
              add_error(port, :valid, "#{port} is invalid")
              return
            end
          end
        end

        privacy_changed = false
        if inputs.include?(:is_public)
          privacy_changed = (camera.is_public? != inputs[:is_public])
        end

        camera.name = name if name
        camera.owner = User.by_login(username) if username
        camera.is_public = inputs[:is_public] if privacy_changed
        camera.is_online = inputs[:is_online] unless inputs[:is_online].nil?

        [:jpg, :mjpg, :h264, :audio, :mpeg].each do |resource|
          url_name = "#{resource}_url"
          unless inputs[url_name].nil?
            unless inputs[url_name].empty?
              inputs[url_name].prepend('/') if inputs[url_name][0,1] != '/'
            end
            if camera.values[:config].has_key?('snapshots')
              camera.values[:config]['snapshots'].merge!({resource => inputs[url_name]})
            else
              camera.values[:config].merge!({'snapshots' => { resource => inputs[url_name]}})
            end
          end
        end

        if inputs[:cam_username] or inputs[:cam_password]
          camera.values[:config].merge!({'auth' => {'basic' => {'username' => inputs[:cam_username].to_s.empty? ? '' : inputs[:cam_username],
                                                                'password' => inputs[:cam_password].to_s.empty? ? '' : inputs[:cam_password]}}})
        end

        camera.timezone = timezone if timezone
        # Update or reset vendor model
        camera.vendor_model =  VendorModel.find(:exid => model, :vendor_id => Vendor.find(:exid => vendor).id) unless model.blank?
        camera.vendor_model = nil if not model.nil? and model.empty?

        unless inputs[:mac_address].nil?
          camera.mac_address = inputs[:mac_address].empty? ? nil : mac_address
        end

        # setup camera GPS location
        unless location_lng.blank? && location_lat.blank?
          begin
            camera.location = { lng: location_lng.to_f, lat: location_lat.to_f }
          rescue ArgumentError
            add_error(location_lng, :valid, "#{location_lng} is invalid")
            add_error(location_lat, :valid, "#{location_lat} is invalid")
            return
          end
        end

        if privacy_changed && !camera.is_public?
          # Camera made private so delete any public shares.
          CameraShare.where(kind: CameraShare::PUBLIC,
                            camera_id: camera.id).delete
        end

        if inputs[:motiondetection_threshold]
          camera.motiondetection_threshold = inputs[:motiondetection_threshold]
        end

        if inputs[:schedule]
          camera.schedule = inputs[:schedule]
        end

        if inputs[:webhook_url]
          camera.webhook_url = inputs[:webhook_url]
        end

        if inputs[:region_of_interest]
          camera.region_of_interest = inputs[:region_of_interest]
        end

        camera.values[:config].merge!({'external_host' => inputs[:external_host].empty? ? '' : inputs[:external_host]}) unless inputs[:external_host].nil?
        camera.values[:config].merge!({'internal_host' => inputs[:internal_host].empty? ? '' : inputs[:internal_host]}) unless inputs[:internal_host].nil?
        camera.discoverable = (inputs[:discoverable] == true) if inputs.include?(:discoverable)
        camera.save

        unless inputs[:external_host].blank?
          # fire off the evr.cm zone update to sidekiq
          DNSUpsertWorker.perform_async(id, inputs[:external_host]) unless Evercam::Config[:testserver]
        end

        camera
      end
    end
  end
end

