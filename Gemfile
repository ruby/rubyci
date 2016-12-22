source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 2.3.3'

gem 'rails', '~> 5.0.0'
gem 'unicorn'

gem 'sass-rails'
gem 'sass-rails-bootstrap'
gem 'jquery-rails'
gem 'coffee-rails'
gem 'uglifier'

group :development do
  gem 'foreman'
  gem 'sqlite3'
end

group :production do
  gem 'pg'
  gem 'newrelic_rpm'
  gem 'airbrake'
end
