# frozen_string_literal: true

require_relative "process_bot/version"

module ProcessBot
  class Error < StandardError; end

  autoload :Capistrano, "#{__dir__}/process_bot/capistrano.rb"
end
