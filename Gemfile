source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 2.5.0'

gem 'rails', '~> 5.1.6'
gem 'unicorn'

gem 'sass-rails'
gem 'sass-rails-bootstrap'
gem 'jquery-rails'
gem 'coffee-rails'
gem 'uglifier'

group :development do
  gem 'foreman'
  gem 'puma'
  gem 'sqlite3'
end

group :production do
  gem 'pg'
  gem 'newrelic_rpm'
  gem 'airbrake'
end
