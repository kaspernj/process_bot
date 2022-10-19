class ProcessBot::Process::Handlers::Sidekiq
  attr_reader :options

  def initialize(options)
    @options = options
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

  def command # rubocop:disable Metrics/AbcSize
    args = []

    options.options.each do |key, value|
      next unless (match = key.to_s.match(/\Asidekiq_(.+)\Z/))

      sidekiq_key = match[1]

      if sidekiq_key == "queue"
        value.split(",").each do |queue|
          args.push "--queue #{queue}"
        end
      else
        args.push "--#{sidekiq_key} #{value}"
      end
    end

    command = "bash -c 'cd #{options.fetch(:release_path)} && "
    command << "#{options.fetch(:bundle_prefix)} " if options.present?(:bundle_prefix)
    command << "bundle exec sidekiq #{args.compact.join(' ')}"
    command << "'"
    command
  end
end
