require "json"

module ProcessBot::Capistrano::SidekiqHelpers # rubocop:disable Metrics/ModuleLength
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

  def process_bot_command(process_bot_data, command)
    raise "No port in process bot data? #{process_bot_data}" unless process_bot_data["port"]

    backend.execute "cd #{release_path} && " \
      "#{SSHKit.config.command_map.prefix[:bundle].join(" ")} bundle exec process_bot " \
      "--command #{command} " \
      "--port #{process_bot_data.fetch("port")}"
  end

  def running_process_bot_processes
    sidekiq_app_name = fetch(:sidekiq_app_name, fetch(:application))
    raise "No :sidekiq_app_name was set" unless sidekiq_app_name

    begin
      processes_output = backend.capture("ps a | grep ProcessBot | grep sidekiq | grep -v '/usr/bin/SCREEN' | grep '#{Regexp.escape(sidekiq_app_name)}'")
    rescue SSHKit::Command::Failed
      # Fails when output is empty (when no processes found through grep)
      puts "No ProcessBot Sidekiq processes found"
      return []
    end

    parse_process_bot_process_from_ps(processes_output)
  end

  def parse_process_bot_process_from_ps(processes_output)
    processes = []
    processes_output.scan(/^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+ProcessBot (\{([^\n]+?)\})$/).each do |process_output|
      process_bot_data = JSON.parse(process_output[4])
      process_bot_pid = process_output[0]
      process_bot_data["process_bot_pid"] = process_bot_pid

      processes << process_bot_data
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

  def start_sidekiq(idx = 0) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    releases = backend.capture(:ls, "-x", releases_path).split
    releases << release_timestamp.to_s if release_timestamp
    releases.uniq

    latest_release_version = releases.last
    raise "Invalid release timestamp: #{release_timestamp}" unless latest_release_version

    args = [
      "--command", "start",
      "--id", "sidekiq-#{latest_release_version}-#{idx}",
      "--application", fetch(:sidekiq_app_name, fetch(:application)),
      "--handler", "sidekiq",
      "--bundle-prefix", SSHKit.config.command_map.prefix[:bundle].join(" "),
      "--sidekiq-environment", fetch(:sidekiq_env),
      "--port", 7050 + idx,
      "--release-path", release_path
    ]

    # Use screen for logging everything which is why this is disabled
    # args += ["--log-file-path", fetch(:sidekiq_log)] if fetch(:sidekiq_log)

    args += ["--sidekiq-require", fetch(:sidekiq_require)] if fetch(:sidekiq_require)
    args += ["--sidekiq-tag", fetch(:sidekiq_tag)] if fetch(:sidekiq_tag)
    args += ["--sidekiq-queues", Array(fetch(:sidekiq_queue)).join(",")] if fetch(:sidekiq_queue)
    args += ["--sidekiq-config", fetch(:sidekiq_config)] if fetch(:sidekiq_config)
    args += ["--sidekiq-concurrency", fetch(:sidekiq_concurrency)] if fetch(:sidekiq_concurrency)
    if (process_options = fetch(:sidekiq_options_per_process))
      args += process_options[idx]
    end
    args += fetch(:sidekiq_options) if fetch(:sidekiq_options)

    screen_args = ["-dmS process-bot--sidekiq--#{idx}-#{latest_release_version}"]

    if (process_bot_sidekiq_log = fetch(:process_bot_sidekig_log))
      screen_args << "-L -Logfile #{process_bot_sidekiq_log}"
    elsif fetch(:sidekiq_log)
      screen_args << "-L -Logfile #{fetch(:sidekiq_log)}"
    end

    process_bot_args = args.compact.map { |arg| "\"#{arg}\"" }

    command = "/usr/bin/screen #{screen_args.join(" ")} " \
      "bash -c 'cd #{release_path} && exec #{SSHKit.config.command_map.prefix[:bundle].join(" ")} bundle exec process_bot #{process_bot_args.join(" ")}'"

    puts "WARNING: A known bug prevents Sidekiq from starting when pty is set (which it is)" if fetch(:pty)
    puts "ProcessBot Sidekiq command: #{command}"

    backend.execute command
  end
end
