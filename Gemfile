source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '2.3.0'

gem 'rails', '~> 4.2.0'
gem 'activeresource', require: 'active_resource'
gem 'actionpack-page_caching'
gem 'unicorn'

gem 'sass-rails'
gem 'sass-rails-bootstrap'
gem 'jquery-rails'
gem 'coffee-rails'
gem 'uglifier'

group :development do
  gem 'heroku'
  gem 'foreman'
  gem 'sqlite3'
end

group :production do
  gem 'pg'
  gem 'rails_12factor'
  gem 'newrelic_rpm'
  gem 'airbrake'
end
