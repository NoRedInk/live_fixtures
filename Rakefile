# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :db do
  task :create do
    case ENV.fetch('DB', nil)
    when 'mysql'
      `mysql -e 'create database live_fixtures'`
    when 'postgres'
      `psql -c 'create database live_fixtures' -U postgres`
      # else
      # do nothing for sqlite3, default
    end
  end
end
