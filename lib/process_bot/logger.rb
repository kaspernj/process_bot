class ProcessBot::Logger
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def error(output)
    logs(output, type: :stderr)
  end

  def log(output, type: :stdout)
    write_output(output, type)

    return unless log_to_file?
    return if type == :debug && !debug_enabled?

    write_log_file(output)
  end

  def logs(output, type: :info, **args)
    log("#{output}\n", type: type, **args)
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

  def write_output(output, type)
    case type
    when :stdout
      $stdout.print output
    when :stderr
      $stderr.print output
    when :info
      $stdout.print output if logging_enabled?
    when :debug
      $stdout.print output if debug_enabled?
    else
      raise "Unknown type: #{type}"
    end
  end

  def write_log_file(output)
    fp_log.write(output)
    fp_log.flush
  end

  def debug_enabled?
    truthy_option?(:debug)
  end

  def logging_enabled?
    truthy_option?(:log) || truthy_option?(:logging) || debug_enabled?
  end

  def truthy_option?(key)
    value = options[key]
    return false if value.nil?
    return value if value == true || value == false

    normalized = value.to_s.strip.downcase
    return false if normalized == "false" || normalized == "0" || normalized == ""

    true
  end
end
