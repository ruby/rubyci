source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 3.4.7'

gem 'rails', '~> 8.1'
gem 'puma'
gem 'bootsnap', require: false
gem "importmap-rails"
gem "propshaft"
gem "dartsass-rails"
gem 'aws-sdk-s3', '~> 1'

group :development, :test do
  gem 'sqlite3'
end

group :production do
  gem 'pg'
end

group :test do
  gem 'test-unit'
end
