source 'https://rubygems.org'

ruby '1.9.3'
gem 'rails', '3.2.8'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier',     '~> 1.0.3'
  gem 'twitter-bootstrap-rails'
end

gem 'jquery-rails'

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

gem 'execjs'
gem 'thin'

group :development do
  gem 'heroku'
  gem 'foreman'
  gem 'sqlite3'
  gem 'libv8'

  gem 'therubyracer', '~> 0.11.0beta5', :require => 'v8'
end

group :production do
  gem 'pg'
  gem 'newrelic_rpm'
end
