require 'aws'
require_relative '../../lib/services'

module Evercam
  class RubySnapshotWorker

    include Sidekiq::Worker

    sidekiq_options queue: :snapshot

    def perform(camera_id, timestamp)
      filepath = "#{camera_id}/snapshots/#{timestamp}.jpg"
      file = Evercam::Services.snapshot_bucket.objects[filepath]

      raise NotFoundError.new(
        "File '#{filepath}' not found in '#{Evercam::Services.snapshot_bucket.name}' bucket"
      ) unless file.exists?

      camera = Camera.by_exid!(camera_id)
      if Snapshot.where(camera: camera, created_at: Time.at(timestamp)).blank?
        Snapshot.create(
          camera_id: camera_id,
          created_at: Time.at(timestamp),
          data: 'S3',
          notes: 'Evercam Proxy'
        )
      end
    end
  end
end
