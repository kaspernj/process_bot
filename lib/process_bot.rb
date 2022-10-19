require_relative "process_bot/version"

module ProcessBot
  class Error < StandardError; end

  autoload :Capistrano, "#{__dir__}/process_bot/capistrano"
  autoload :ClientSocket, "#{__dir__}/process_bot/client_socket"
  autoload :ControlSocket, "#{__dir__}/process_bot/control_socket"
  autoload :Logger, "#{__dir__}/process_bot/logger"
  autoload :Options, "#{__dir__}/process_bot/options"
  autoload :Process, "#{__dir__}/process_bot/process"
end
