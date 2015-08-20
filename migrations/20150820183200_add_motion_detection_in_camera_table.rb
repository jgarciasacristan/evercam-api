Sequel.migration do
  up do
    alter_table(:cameras) do
      add_column :motiondetection_threshold, :integer, null: true
      add_column :schedule, :json, null: true
      add_column :webhook_url, String, null: true
      add_column :region_of_interest, :json, null: true
    end
  end

  down do
    alter_table(:cameras) do
      drop_column :motiondetection_threshold
      drop_column :schedule
      drop_column :webhook_url
      drop_column :region_of_interest
    end
  end
end
