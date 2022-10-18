module ProcessBot::Capistrano::SidekiqHelpers
  def sidekiq_require
    "--require #{fetch(:sidekiq_require)}" if fetch(:sidekiq_require)
  end

  def sidekiq_config
    "--config #{fetch(:sidekiq_config)}" if fetch(:sidekiq_config)
  end

  def sidekiq_concurrency
    "--concurrency #{fetch(:sidekiq_concurrency)}" if fetch(:sidekiq_concurrency)
  end

  def sidekiq_queues
    Array(fetch(:sidekiq_queue)).map do |queue|
      "--queue #{queue}"
    end.join(" ")
  end

  def sidekiq_logfile
    fetch(:sidekiq_log)
  end

  def switch_user(role, &block)
    su_user = sidekiq_user(role)
    if su_user == role.user
      yield
    else
      as su_user, &block
    end
  end

  VALID_SIGNALS = ["TERM", "TSTP"].freeze
  def stop_sidekiq(pid:, signal:)
    raise "Invalid PID: #{pid}" unless pid.to_s.match?(/\A\d+\Z/)
    raise "Invalid signal: #{signal}" unless VALID_SIGNALS.include?(signal)

    backend.execute "kill -#{signal} #{pid}"
  end

  def stop_sidekiq_after_time(pid:, signal:)
    raise "Invalid PID: #{pid}" unless pid.to_s.match?(/\A\d+\Z/)
    raise "Invalid signal: #{signal}" unless VALID_SIGNALS.include?(signal)

    time = ENV["STOP_AFTER_TIME"] || fetch(:sidekiq_stop_after_time)
    raise "Invalid time: #{time}" unless time.to_s.match?(/\A\d+\Z/)

    backend.execute "screen -dmS stopsidekiq#{pid} bash -c \"sleep #{time} && kill -#{signal} #{pid}\""
  end

  def running_sidekiq_processes
    sidekiq_app_name = fetch(:sidekiq_app_name, fetch(:application))
    raise "No :sidekiq_app_name was set" unless sidekiq_app_name

    begin
      processes_output = backend.capture("ps a | egrep 'sidekiq ([0-9]+\.[0-9]+\.[0-9]+) #{Regexp.escape(sidekiq_app_name)}'")
    rescue SSHKit::Command::Failed
      # Fails when output is empty (when no processes found through grep)
      puts "No Sidekiq processes found"
      return []
    end

    processes = []
    processes_output.scan(/^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)$/).each do |process_output|
      sidekiq_pid = process_output[0]

      processes << {pid: sidekiq_pid}
    end

    processes
  end

  def sidekiq_user(role = nil)
    if role.nil?
      fetch(:sidekiq_user)
    else
      properties = role.properties
      properties.fetch(:sidekiq_user) || # local property for sidekiq only
        fetch(:sidekiq_user) ||
        properties.fetch(:run_as) || # global property across multiple capistrano gems
        role.user
    end
  end

  def expanded_bundle_path
    backend.capture(:echo, SSHKit.config.command_map[:bundle]).strip
  end

  def start_sidekiq(idx = 0) # rubocop:disable Metrics/AbcSize
    releases = backend.capture(:ls, "-x", releases_path).split
    releases << release_timestamp.to_s if release_timestamp
    releases.uniq

    latest_release_version = releases.last
    raise "Invalid release timestamp: #{release_timestamp}" unless latest_release_version

    args = [
      "--id", "sidekiq-#{latest_release_version}-#{idx}",
      "--handler", "sidekiq",
      "--bundle-prefix", SSHKit.config.command_map.prefix[:bundle].join(" "),
      "--sidekiq-environment", fetch(:sidekiq_env),
      "--port", 7050 + idx
    ]
    args += ["--log-file-path", fetch(:sidekiq_log)] if fetch(:sidekiq_log)
    args += ["--sidekiq-require", fetch(:sidekiq_require)] if fetch(:sidekiq_require)
    args += ["--sidekiq-tag", fetch(:sidekiq_tag)] if fetch(:sidekiq_tag)
    args += ["--sidekiq-queues", Array(fetch(:sidekiq_queue)).join(",")] if fetch(:sidekiq_queue)
    args += ["--sidekiq-config", fetch(:sidekiq_config)] if fetch(:sidekiq_config)
    args += ["--sidekiq-concurrency", fetch(:sidekiq_concurrency)] if fetch(:sidekiq_concurrency)
    if (process_options = fetch(:sidekiq_options_per_process))
      args += process_options[idx]
    end
    args += fetch(:sidekiq_options) if fetch(:sidekiq_options)

    screen_args = ["-dmS sidekiq-#{idx}-#{latest_release_version}"]
    screen_args << "-L -Logfile #{fetch(:sidekiq_log)}" if fetch(:sidekiq_log)

    process_bot_args = args.compact.map { |arg| "\"#{arg}\"" }

    command = "/usr/bin/screen #{screen_args.join(" ")} " \
      "bash -c 'cd #{release_path} && #{SSHKit.config.command_map.prefix[:bundle].join(" ")} bundle exec process_bot #{process_bot_args.join(" ")}'"

    puts "WARNING: A known bug prevents Sidekiq from starting when pty is set (which it is)" if fetch(:pty)
    puts "ProcessBot Sidekiq command: #{command}"

    backend.execute command
  end
end
