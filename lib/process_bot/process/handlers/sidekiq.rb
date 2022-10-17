class ProcessBot::Process::Handlers::Sidekiq
  attr_reader :id

  def initialize(id:)
    @id = id
  end

  def command
    args = []
    args.push "--environment #{fetch(:sidekiq_env)}"
    # args.push "--logfile #{fetch(:sidekiq_log)}" if fetch(:sidekiq_log)
    args.push "--require #{fetch(:sidekiq_require)}" if fetch(:sidekiq_require)
    args.push "--tag #{fetch(:sidekiq_tag)}" if fetch(:sidekiq_tag)
    Array(fetch(:sidekiq_queue)).each do |queue|
      args.push "--queue #{queue}"
    end
    args.push "--config #{fetch(:sidekiq_config)}" if fetch(:sidekiq_config)
    args.push "--concurrency #{fetch(:sidekiq_concurrency)}" if fetch(:sidekiq_concurrency)
    if (process_options = fetch(:sidekiq_options_per_process))
      args.push process_options[idx]
    end
    # use sidekiq_options for special options
    args.push fetch(:sidekiq_options) if fetch(:sidekiq_options)

    releases = backend.capture(:ls, "-x", releases_path).split
    releases << release_timestamp.to_s if release_timestamp
    releases.uniq

    latest_release_version = releases.last
    raise "Invalid release timestamp: #{release_timestamp}" unless latest_release_version

    screen_args = ["-dmS sidekiq-#{idx}-#{latest_release_version}"]
    screen_args << "-L -Logfile #{fetch(:sidekiq_log)}" if fetch(:sidekiq_log)

    # command = "/usr/bin/tmux new -d -s sidekiq#{idx} '#{SSHKit.config.command_map.prefix[:sidekiq].join(" ")} sidekiq #{args.compact.join(' ')}'"
    command = "/usr/bin/screen #{screen_args.join(" ")} " \
      "bash -c 'cd #{release_path} && #{SSHKit.config.command_map.prefix[:sidekiq].join(" ")} sidekiq #{args.compact.join(' ')}'"

    puts "WARNING: A known bug prevents Sidekiq from starting when pty is set (which it is)" if fetch(:pty)

    command
  end
end
