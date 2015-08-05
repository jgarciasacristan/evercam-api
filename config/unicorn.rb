worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout 30
preload_app true
pid 'unicorn.pid'

before_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  Sequel::Model.db.disconnect if defined?(Sequel::Model.db)
  Snapshot.db.disconnect if defined?(Snapshot.db)
  CameraActivity.db.disconnect if defined?(CameraActivity.db)
end

after_fork do |server, worker|
  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  Sequel::Model.db = Sequel.connect(Evercam::Config[:database])
  Snapshot.db = Sequel.connect(Evercam::Config[:snaps_database], max_connections: 20)
  CameraActivity.db = Sequel.connect(Evercam::Config[:snaps_database], max_connections: 20)
end
