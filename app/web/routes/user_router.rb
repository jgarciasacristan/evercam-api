require_relative "./web_router"
require_relative "../../../lib/models"
require_relative "../../../app/api/v1/helpers/with_auth"

module Evercam
  class WebUserRouter < WebRouter

    helpers do
      def auth
        WithAuth.new(env)
      end
    end

    get '/users/:username' do |username|
      @user = User.by_login(username)
      raise NotFoundError, 'Username does not exist' unless @user

      begin
        auth.allow? { |r| @user.allow?(:view, r) }
        @cameras = Camera.where(:owner_id => @user.id)
      rescue AuthenticationError, AuthorizationError
        @cameras = Camera.where(:owner_id => @user.id, :is_public => true)
      end

      @vendors = Vendor.order(:name)
      @models = Firmware
      erb 'users/user_view'.to_sym

    end

    get '/users/:username/profile' do |username|
      @user = User.by_login(username)
      raise NotFoundError, 'Username does not exist' unless @user

      auth.allow? { |r| @user.allow?(:view, r) }

      erb 'users/user_profile'.to_sym

    end

    get '/users/:username/cameras/:camera' do |username, camera|
      @user = User.by_login(username)
      raise NotFoundError, 'Username does not exist' unless @user

      auth.allow? { |r| @user.allow?(:view, r) }

      @models = Firmware.to_hash(:id, :name)
      @camera = Camera.by_exid(camera)
      raise NotFoundError, 'Camera does not exist' unless @camera
      erb 'users/cameras/camera_view'.to_sym
    end

  end
end
