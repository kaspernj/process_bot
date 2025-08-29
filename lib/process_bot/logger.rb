class ProcessBot::Logger
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def error(output)
    logs(output, type: :stderr)
  end

  def log(output, type: :stdout)
    if type == :stdout || (type == :debug && options[:debug])
      $stdout.print output
    elsif type == :stderr
      $stderr.print output
    else
      raise "Unknown type: #{type}"
    end

    return unless log_to_file?

    fp_log.write(output)
    fp_log.flush
  end

  def logs(output, **args)
    log("#{output}\n", **args)
  end

  def log_file_path
    options.fetch(:log_file_path)
  end

  def log_to_file?
    options.present?(:log_file_path)
  end

  def fp_log
    @fp_log ||= File.open(log_file_path, "a") if log_to_file?
  end
end
