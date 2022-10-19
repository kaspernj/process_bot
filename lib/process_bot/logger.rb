class ProcessBot::Logger
  attr_reader :options

  def initialize(options:)
    @options = options
  end

  def log(output)
    return unless logging?

    fp_log.write(output)
    fp_log.flush
  end

  def log_file_path
    options.fetch(:log_file_path)
  end

  def logging?
    options.present?(:log_file_path)
  end

  def fp_log
    @fp_log ||= File.open(log_file_path, "a") if logging?
  end
end