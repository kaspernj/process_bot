class ProcessBot::Options
  attr_reader :options

  def initialize(options = {})
    @options = options
  end

  def [](key)
    options[key]
  end

  def events
    @events ||= begin
      require "knjrbfw"

      event_handler = ::Knj::Event_handler.new
      event_handler.add_event(name: :on_process_started)
      event_handler.add_event(name: :on_socket_opened)
      event_handler
    end
  end

  def fetch(*args, **opts, &blk)
    options.fetch(*args, **opts, &blk)
  end

  def present?(key)
    return true if options.key?(key) && options[key]

    false
  end

  def set(key, value)
    options[key] = value
  end
end
