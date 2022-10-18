class ProcessBot::Process::Handlers::Sidekiq
  attr_reader :options

  def initialize(options)
    @options = options

    set_defaults
  end

  def fetch(*args, **opts)
    options.fetch(*args, **opts)
  end

  def set_option(key, value)
    raise "Unknown option for Sidekiq handler: #{key}" unless options.key?(key)

    set(key, value)
  end

  def set(*args, **opts)
    options.set(*args, **opts)
  end

  def set_defaults
    set :sidekiq_default_hooks, true
    set :sidekiq_pid, -> { File.join(shared_path, "tmp", "pids", "sidekiq.pid") }
    set :sidekiq_timeout, 10
    set :sidekiq_roles, fetch(:sidekiq_role, :app)
    set :sidekiq_processes, 1
    set :sidekiq_options_per_process, nil
  end

  def command # rubocop:disable Metrics/AbcSize
    args = []
    args.push "--environment #{fetch(:sidekiq_env)}"
    args.push "--require #{fetch(:sidekiq_require)}" if options.present?(:sidekiq_require)
    args.push "--tag #{fetch(:sidekiq_tag)}" if options.present?(:sidekiq_tag)

    if options.present?(:sidekiq_queue)
      Array(fetch(:sidekiq_queue)).each do |queue|
        args.push "--queue #{queue}"
      end
    end

    args.push "--config #{fetch(:sidekiq_config)}" if options.present?(:sidekiq_config)
    args.push "--concurrency #{fetch(:sidekiq_concurrency)}" if options.present?(:sidekiq_concurrency)
    if (process_options = fetch(:sidekiq_options_per_process))
      args.push process_options[idx]
    end
    # use sidekiq_options for special options
    args.push fetch(:sidekiq_options) if options.present?(:sidekiq_options)

    "bundle exec sidekiq #{args.compact.join(' ')}"
  end
end
