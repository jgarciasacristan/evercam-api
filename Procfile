web: bundle exec rackup -s Puma -O Threads=0:4 config.ru -p $PORT
worker: bundle exec sidekiq -c 5 -r ./scripts/sidekiq_setup.rb

