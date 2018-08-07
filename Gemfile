source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 2.5.1'

gem 'rails', '~> 5.2.0'
gem 'unicorn'
gem 'bootsnap'

gem 'sass-rails'
gem 'sass-rails-bootstrap'
gem 'jquery-rails'
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
