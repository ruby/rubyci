source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 3.4.1'

gem 'rails', '~> 8.0'
gem 'puma'
gem 'bootsnap', require: false
gem "importmap-rails"
gem "propshaft"
gem "dartsass-rails"
gem 'aws-sdk-s3', '~> 1'

group :development do
  gem 'sqlite3'
end

group :production do
  gem 'pg'
end
