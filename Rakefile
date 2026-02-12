# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

def bump_patch_version(version_path)
  version_content = File.read(version_path)
  version_match = version_content.match(/VERSION = "(\d+)\.(\d+)\.(\d+)"\.freeze/)
  raise "Could not find current version in #{version_path}" unless version_match

  major = version_match[1].to_i
  minor = version_match[2].to_i
  patch = version_match[3].to_i + 1

  new_version = "#{major}.#{minor}.#{patch}"
  new_content = version_content.sub(version_match[0], "VERSION = \"#{new_version}\".freeze")
  File.write(version_path, new_content)

  new_version
end

namespace :release do
  desc "Bump patch version, run bundle, commit version bump, build gem, and push gem"
  task :patch do
    version_path = "lib/process_bot/version.rb"
    new_version = bump_patch_version(version_path)

    puts "Bumped version to #{new_version}"

    sh "bundle install"
    sh "git add #{version_path} Gemfile.lock"
    sh "git commit -m \"Bump version to #{new_version}\""
    sh "bundle exec rake build"

    gem_path = "pkg/process_bot-#{new_version}.gem"
    raise "Expected gem file was not built: #{gem_path}" unless File.exist?(gem_path)

    sh "gem push #{gem_path}"
  end
end

task default: %i[spec rubocop]
