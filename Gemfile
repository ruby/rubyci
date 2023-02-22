source 'https://rubygems.org'

ruby ENV['CUSTOM_RUBY_VERSION'] || '~> 3.2.1'

gem 'rails', '~> 7.0'
gem 'puma'
gem 'bootsnap'
gem "importmap-rails"
gem "dartsass-rails"
gem 'aws-sdk-s3', '~> 1'

group :development do
  gem 'foreman'
  gem 'sqlite3'
  gem 'listen'
end

group :production do
  gem 'pg'
end
