require_relative './presenter'

module Evercam
  module Presenters
    class MotionDetection < Presenter

      root :motion_detections

      expose :camera_id,
        documentation: {
        type: 'string',
        desc: '',
        required: true
      }

      expose :threshold,
        documentation: {
        type: 'integer',
        desc: '',
        required: true
      }

      expose :region_of_interest,
        documentation: {
        type: 'json',
        desc: '',
        required: true
      }

      expose :datetime,
        documentation: {
        type: 'datetime',
        desc: '',
        required: true
      }

      expose :recent_images,
        documentation: {
        type: 'string',
        desc: '',
        required: true
      }
    end
  end
end
