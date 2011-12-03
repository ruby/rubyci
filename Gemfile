source 'http://rubygems.org'

gem 'rails', '3.1.1'

if /\Amgk-/ =~ `hostname`
  Bundler.settings.without = %w/development test heroku/
end

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
  gem 'uglifier'
end

gem 'jquery-rails'
gem 'execjs'
gem 'thin'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end

group :development do
  gem 'sqlite3'
  gem "therubyracer"
end

group :production do
end
group :mogok do
  gem "therubyracer"
  gem 'mysql2'
end
group :heroku do
  gem 'therubyracer-heroku'
  gem 'pg'
  gem 'newrelic_rpm'
end
