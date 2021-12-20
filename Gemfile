source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 3.0.2'

gem 'rails', '~> 7.0.0'
gem 'puma'
gem 'bootsnap'

gem 'sass-rails'
gem 'bootstrap-sass'
gem 'jquery-rails'
gem 'uglifier'

gem 'aws-sdk-s3', '~> 1'

group :development do
  gem 'foreman'
  gem 'sqlite3'
  gem 'listen'
end

group :production do
  gem 'pg'
  gem 'newrelic_rpm'
  gem 'airbrake'
end
