#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Rubyci::Application.load_tasks

# Add chkbuild-ruby-info tests to the default test task
namespace :test do
  desc "Run chkbuild-ruby-info tests"
  task :chkbuild_ruby_info do
    $LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
    Dir.glob('test/chkbuild-ruby-info/test_*.rb').each { |f| require_relative f }
  end
end

# Enhance the default test task to include chkbuild-ruby-info tests
Rake::Task['test'].enhance(['test:chkbuild_ruby_info'])
