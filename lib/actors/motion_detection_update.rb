module Evercam
  module Actors
    class MotionDetectionUpdate < Mutations::Command

      required do
        string :id
        string :camera_id
      end

      optional do
        integer :threshold
        string :region_of_interest
        datetime :datetime
        string :recent_images
      end

      def execute
        camera = Camera.by_exid!(inputs[:camera_id])
        motion_detection = MotionDetection.where(id: inputs[:id]).first
        add_error(:cloud_recording, :exists, "CloudRecording setting does not exist") if cloud_recording.blank?

        unless inputs["region_of_interest"].blank?
          begin
            region_of_interest = JSON.parse(inputs["region_of_interest"])
          rescue => _e
            add_error(:region_of_interest, :invalid, "The parameter 'region_of_interest' isn't formatted as a proper JSON.")
          end
        end

        motion_detection.threshold = inputs["threshold"] unless inputs["threshold"].blank?
        motion_detection.region_of_interest = motion_detection.region_of_interest.merge(region_of_interest)
        motion_detection.datetime = inputs["datetime"] unless inputs["datetime"].blank?
        motion_detection.recent_images = inputs["recent_images"] unless inputs["recent_images"].blank?
        motion_detection.save

        motion_detection
      end
    end
  end
end
