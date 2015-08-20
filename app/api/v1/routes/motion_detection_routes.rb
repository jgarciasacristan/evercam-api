module Evercam
  class V1MotionDetectionRoutes < Grape::API

    #---------------------------------------------------------------------------
    # GET /v1/cameras/:id/apps/motion_detection
    #---------------------------------------------------------------------------
    # desc '', {
    #   entity: Evercam::Presenters::MotionDetection
    # }
    # params do
    #   requires :id, type: String, desc: "Camera Id."
    # end
    # get '/cameras/:id/apps/motion-detections' do
    #   camera = get_cam(params[:id])
    #   rights = requester_rights_for(camera)
    #   raise AuthorizationError.new if !rights.allow?(AccessRight::VIEW)

    #   motion_detection = MotionDetection.where(camera_id: camera.id).first

    #   present Array(cloud_recording), with: Presenters::MotionDetection
    # end

    #---------------------------------------------------------------------------
    # POST /v1/cameras/:id/apps/motion_detection
    #---------------------------------------------------------------------------
    desc '', {
      entity: Evercam::Presenters::MotionDetection
    }
    params do
      # camera_od
      requires :id, type: String, desc: "Camera Id."
      requires :threshold, type: Integer, desc: "Threshold level to trigger motion detection"
      requires :schedule, type: String, desc: "JSON formatted string schedule for week"
      requires :webhook_url, type: String, desc: "URL that will be called after motion detection is triggered"
      requires :region_of_interest, type: String, desc: "JSON formatted string with polygon definition where threshold will be accounted"
    end
    post '/cameras/:id/apps/motion-detections' do
      camera = get_cam(params[:id])
      rights = requester_rights_for(camera)
      raise AuthorizationError.new if !rights.allow?(AccessRight::VIEW)

      outcome = Actors::MotionDetectionCreate.run(params)
      unless outcome.success?
        raise OutcomeError, outcome.to_json
      end
      present Array(outcome.result), with: Presenters::MotionDetection
    end

    #---------------------------------------------------------------------------
    # PATCH /v1/cameras/:id/apps/motion_detection
    #---------------------------------------------------------------------------
    # desc '', {
    #   entity: Evercam::Presenters::MotionDetection
    # }
    # params do
    #   requires :id, type: String, desc: "Camera Id."
    #   optional :frequency, type: Integer, desc: "Frequency of Snapshots per minute"
    #   optional :storage_duration, type: Integer, desc: "Storage Duration"
    #   optional :schedule, type: String, desc: "Schedule"
    # end
    # patch '/cameras/:id/apps/motion-detections' do
    #   camera = get_cam(params[:id])
    #   rights = requester_rights_for(camera)
    #   raise AuthorizationError.new if !rights.allow?(AccessRight::VIEW)

    #   outcome = Actors::MotionDetectionUpdate.run(params)
    #   unless outcome.success?
    #     raise OutcomeError, outcome.to_json
    #   end
    #   present Array(outcome.result), with: Presenters::MotionDetection
    # end

    #---------------------------------------------------------------------------
    # DELETE /v1/cameras/:id/apps/motion_detection
    #---------------------------------------------------------------------------
    # desc '', {
    #   entity: Evercam::Presenters::MotionDetection
    # }
    # params do
    #   requires :id, type: String, desc: "Camera Id."
    # end
    # delete '/cameras/:id/apps/motion-detections' do
    #   camera = get_cam(params[:id])
    #   rights = requester_rights_for(camera)
    #   raise AuthorizationError.new if !rights.allow?(AccessRight::VIEW)

    #   motion_detection = MotionDetection.where(camera_id: camera.id).first
    #   motion_detection.delete

    #   {}
    # end
  end
end