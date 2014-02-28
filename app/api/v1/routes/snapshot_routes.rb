require_relative '../presenters/snapshot_presenter'

# Disable File validation, it doesn't work
module Grape
  module Validations
    class CoerceValidator < SingleOptionValidator
      alias_method :validate_param_old!, :validate_param!

      def validate_param!(attr_name, params)
        unless @option.to_s == 'File'
          validate_param_old!(attr_name, params)
        end

      end
    end
  end
end

module Evercam
  class V1SnapshotSinatraRoutes < Sinatra::Base

    get '/cameras/:id/snapshot.jpg' do
      begin
        camera = ::Camera.by_exid!(params[:id])
      rescue NotFoundError => e
        halt 404, e.message
      end

      begin
        auth = WithAuth.new(env)
        auth.allow? { |token| camera.allow?(AccessRight::SNAPSHOT, token) }
      rescue AuthenticationError => e
        halt 401, e.message
      end

      response = nil

      camera.endpoints.each do |endpoint|
        next unless (endpoint.public? rescue false)
        con = Net::HTTP.new(endpoint.host, endpoint.port)

        begin
          con.open_timeout =  Evercam::Config[:api][:timeout]
          response = con.get(camera.config['snapshots']['jpg'])
          if response.is_a?(Net::HTTPSuccess)
            break
          end
        rescue Net::OpenTimeout
          # offline
        rescue Exception => e
          # we weren't expecting this (famous last words)
          puts e
        end
      end
      if response.is_a?(Net::HTTPSuccess)
        headers 'Content-Type' => 'image/jpg; charset=utf8'
        response.body
      else
        status 503
        'Camera offline'
      end
    end

  end

  class V1SnapshotRoutes < Grape::API

    include WebErrors

    namespace :cameras do
      params do
        requires :id, type: String, desc: "Camera Id."
      end
      route_param :id do

        desc 'Returns the list of all snapshots currently stored for this camera'
        get 'snapshots' do
          camera = ::Camera.by_exid!(params[:id])
          auth.allow? { |token| camera.allow?(AccessRight::SNAPSHOT, token) }

          present camera.snapshots, with: Presenters::Snapshot, models: true
        end

        desc 'Returns the snapshot stored for this camera closest to the given timestamp', {
          entity: Evercam::Presenters::Snapshot
        }
        params do
          requires :timestamp, type: Integer, desc: "Snapshot Unix timestamp."
          optional :with_data, type: Boolean, desc: "Should it send image data?"
          optional :range, type: Integer, desc: "Time range in seconds around specified timestamp"
        end
        get 'snapshots/:timestamp' do
          camera = ::Camera.by_exid!(params[:id])
          auth.allow? { |token| camera.allow?(AccessRight::SNAPSHOT, token) }

          snap = Snapshot.by_ts!(Time.at(params[:timestamp].to_i), params[:range].to_i)
          puts params[:with_data]

          present Array(snap), with: Presenters::Snapshot, with_data: params[:with_data]
        end

        desc 'Fetches a snapshot from the camera and stores it using the current timestamp'
        params do
          optional :notes, type: String, desc: "Optional text note for this snapshot"
        end
        post 'snapshots' do
          camera = ::Camera.by_exid!(params[:id])
          auth.allow? { |token| camera.allow?(AccessRight::EDIT, token) }

          outcome = Actors::SnapshotFetch.run(params)
          raise OutcomeError, outcome unless outcome.success?

          present Array(outcome.result), with: Presenters::Snapshot
        end

        desc 'Stores the supplied snapshot image data for the given timestamp'
        params do
          requires :timestamp, type: Integer, desc: "Snapshot Unix timestamp."
          requires :data, type: File, desc: "Image file."
          optional :notes, type: String, desc: "Optional text note for this snapshot"
        end
        post 'snapshots/:timestamp' do
          camera = ::Camera.by_exid!(params[:id])
          auth.allow? { |token| camera.allow?(AccessRight::EDIT, token) }

          outcome = Actors::SnapshotCreate.run(params)
          raise OutcomeError, outcome unless outcome.success?

          present Array(outcome.result), with: Presenters::Snapshot
        end

        desc 'Deletes any snapshot for this camera which exactly matches the timestamp'
        params do
          requires :timestamp, type: Integer, desc: "Snapshot Unix timestamp."
        end
        delete 'snapshots/:timestamp' do
          camera = ::Camera.by_exid!(params[:id])
          auth.allow? { |token| camera.allow?(AccessRight::EDIT, token) }

          Snapshot.by_ts!(Time.at(params[:timestamp].to_i)).destroy
          {}
        end

      end
    end

  end
end

