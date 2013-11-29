source 'https://rubygems.org'

ruby '2.0.0'
gem 'rails', '3.2.13'

gem 'jquery-rails'
gem 'execjs'
gem 'thin'
gem 'sass-rails-bootstrap'

group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '~> 1.0.3'
end

group :development do
  gem 'heroku'
  gem 'foreman'
  gem 'sqlite3'
  gem "libv8"
  gem 'therubyracer', '~> 0.11.4', :require => 'v8'
end

group :production do
  gem 'pg'
  gem 'newrelic_rpm'
end
