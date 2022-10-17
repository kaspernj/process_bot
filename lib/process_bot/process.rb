class ProcessBot::Process
  module Handlers
  end

  autoload :Runner, "#{__dir__}/process/runner"

  attr_reader :id, :handler

  def initialize(id:, handler:)
    @id = id
    @handler = handler
  end

  def execute!
    require_relative "process/handlers/#{handler}"
    handler_instance = ProcessBot::Process::Handlers.const_get(StringCases.snake_to_camel(handler)).new(id: id)
    runner = ProcessBot::Process::Runner.new(command: handler_instance.command)
  end
end
