web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker: bundle exec rake jobs:work
scheduler: bundle exec rake lytit:scheduler
whacamole: bundle exec whacamole -c ./config/whacamole.rb
