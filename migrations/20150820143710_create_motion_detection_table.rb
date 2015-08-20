Sequel.migration do
  up do
    create_table(:motion_detection) do
      primary_key :id
      foreign_key :camera_id, :cameras, on_delete: :cascade, null: false
      column :threshold, :integer, null: true, default: 0
      column :region_of_interest, :json, null: true
      column :datetime, DateTime, null: true
      column :recent_images, String, null: true
    end
  end

  down do
    drop_table(:motion_detection)
  end
end
