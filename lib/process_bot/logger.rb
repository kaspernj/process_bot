class ProcessBot::Logger
  attr_reader :fp_log, :options

  def initialize(options:)
    @options = options

    open_file if logging?
  end

  def log(output)
    return unless logging?

    fp_log&.write(output)
    fp_log&.flush
  end

  def log_file_path
    options.fetch(:log_file_path)
  end

  def logging?
    options.present?(:log_file_path
  end

  def open_file
    @fp_log = File.open(log_file_path, "a")
  end
end
