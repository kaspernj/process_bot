class ProcessBot::Process::RunnerInstance
  attr_reader :runner, :thread

  def initialize(runner:, event_queue:, logger:)
    @runner = runner
    @event_queue = event_queue
    @logger = logger
  end

  def start
    @thread = Thread.new do
      runner.run
      event_queue << {type: :stopped, runner_instance: self}
    rescue => e # rubocop:disable Style/RescueStandardError
      logger.error e.message
      logger.error e.backtrace
      event_queue << {type: :error, runner_instance: self, error: e}
    end
  end

  def running?
    runner.running?
  end

private

  attr_reader :event_queue, :logger
end
