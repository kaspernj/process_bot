# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

Dir[File.expand_path("lib/tasks/**/*.rake", __dir__)].each { |f| load f }

task default: %i[spec rubocop]
