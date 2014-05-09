source 'https://rubygems.org'

ruby '2.1.2' unless ENV['DEV']
gem 'rails', '~> 3.2'
gem 'thin'

gem 'sass-rails'
gem 'sass-rails-bootstrap'
gem 'jquery-rails'
gem 'coffee-rails'
gem 'uglifier'

group :development do
  gem 'heroku'
  gem 'foreman'
  gem 'sqlite3'
  gem 'therubyracer'
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
  gem 'newrelic_rpm'
  gem 'airbrake'
end
