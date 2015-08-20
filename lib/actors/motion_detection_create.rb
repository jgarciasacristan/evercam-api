module Evercam
  module Actors
    class MotionDetectionCreate < Mutations::Command
      required do
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

        motion_detection = MotionDetection.create(
          camera: camera,
          region_of_interest: region_of_interest
          threshold: inputs["threshold"],
          datetime: inputs["datetime"],
          recent_images: inputs["recent_images"]
        )

        unless inputs["region_of_interest"].blank?
          begin
            motion_detection.region_of_interest = JSON.parse(inputs["region_of_interest"])
          rescue => _e
            add_error(:region_of_interest, :invalid, "The parameter 'region_of_interest' isn't formatted as a proper JSON.")
          end
        end

        motion_detection.save
        motion_detection
      end
    end
  end
end
