require "English"
require "fileutils"
require "pathname"
require "rubygems/version"
require "shellwords"

class ProcessBotRubygemsRelease
  VERSION_FILE = Pathname.new(File.expand_path("../process_bot/version.rb", __dir__)) unless const_defined?(:VERSION_FILE)

  def call
    ensure_clean_worktree!
    checkout_master!
    fetch!
    merge!

    next_version = determine_next_version

    bump_version!(next_version)
    commit!(next_version)
    push!
    gem_file = build_gem!(next_version)
    push_gem!(gem_file)
    delete_gem_file!(gem_file)
  rescue StandardError
    warn "Release failed."
    raise
  end

private

  def ensure_clean_worktree!
    dirty_entries = git_status_lines.grep_v(%r{\A\?\? process_bot-[^/]+\.gem\z})
    return if dirty_entries.empty?

    raise "Working tree must be clean before releasing:\n#{dirty_entries.join("\n")}"
  end

  def checkout_master!
    run!("git", "checkout", "master")
  end

  def fetch!
    run!("git", "fetch", remote_name)
  end

  def merge!
    run!("git", "merge", "--ff-only", "#{remote_name}/master")
  end

  def determine_next_version
    requested_version || bumped_version
  end

  def requested_version
    version = ENV["VERSION"]&.strip
    return if version.to_s.empty?

    Gem::Version.new(version)
    version
  end

  def bumped_version
    major, minor, patch = version_segments

    case bump_type
    when "major"
      format_version(major + 1, 0, 0)
    when "minor"
      format_version(major, minor + 1, 0)
    when "patch"
      format_version(major, minor, patch + 1)
    else
      raise "Unsupported BUMP=#{bump_type.inspect}. Use patch, minor, major, or VERSION=x.y.z."
    end
  end

  def version_segments
    @version_segments ||= begin
      segments = Gem::Version.new(current_version).segments
      segments << 0 while segments.length < 3
      segments
    end
  end

  def current_version
    @current_version ||= VERSION_FILE.read[/VERSION = "([^"]+)"\.freeze/, 1] || raise("Could not find current version")
  end

  def format_version(major, minor, patch)
    [major, minor, patch].join(".")
  end

  def bump_version!(next_version)
    raise "Next version must differ from current version" if next_version == current_version

    VERSION_FILE.write(
      VERSION_FILE.read.sub(
        /VERSION = "[^"]+"\.freeze/,
        %(VERSION = "#{next_version}".freeze)
      )
    )

    sync_lockfile!
    run!("git", "add", VERSION_FILE.to_s, "Gemfile.lock")
  end

  def sync_lockfile!
    run!("bundle", "lock")
  end

  def commit!(next_version)
    run!("git", "commit", "-m", "Release #{next_version}")
  end

  def push!
    run!("git", "push", remote_name, "master")
  end

  def build_gem!(next_version)
    gem_file = "process_bot-#{next_version}.gem"
    run!("gem", "build", "process_bot.gemspec")
    gem_file
  end

  def push_gem!(gem_file)
    run!("gem", "push", gem_file)
  end

  def delete_gem_file!(gem_file)
    FileUtils.rm_f(gem_file)
  end

  def git_status_lines
    capture!("git", "status", "--porcelain").split("\n").reject(&:empty?)
  end

  def bump_type
    ENV.fetch("BUMP", "patch")
  end

  def remote_name
    ENV.fetch("REMOTE", "origin")
  end

  def capture!(*command)
    output = `#{command.map { |part| Shellwords.escape(part) }.join(" ")}`
    raise "Command failed: #{command.join(' ')}" unless $CHILD_STATUS&.success?

    output
  end

  def run!(*command)
    return if system(*command)

    raise "Command failed: #{command.join(' ')}"
  end
end

namespace :release do
  desc "Release a patch version from master by fetching, fast-forward merging, bumping version, refreshing Gemfile.lock, pushing, and publishing"
  task :patch do
    ENV["BUMP"] = "patch"
    ProcessBotRubygemsRelease.new.call
  end

  desc "Release a minor version from master by fetching, fast-forward merging, bumping version, refreshing Gemfile.lock, pushing, and publishing"
  task :minor do
    ENV["BUMP"] = "minor"
    ProcessBotRubygemsRelease.new.call
  end

  desc "Release a major version from master by fetching, fast-forward merging, bumping version, refreshing Gemfile.lock, pushing, and publishing"
  task :major do
    ENV["BUMP"] = "major"
    ProcessBotRubygemsRelease.new.call
  end

  desc "Release the gem from master by fetching, fast-forward merging, bumping version, refreshing Gemfile.lock, pushing, and publishing"
  task :rubygems do
    ProcessBotRubygemsRelease.new.call
  end
end
