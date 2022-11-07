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

  def application_basename
    File.basename(Dir.pwd)
  end

  def possible_process_titles
    possible_names = []

    # Sidekiq name can by current Rails root base name
    possible_names << application_basename

    # Sidekiq name can be set tag name (but we wrongly read application for some reason?)
    possible_names << options.fetch(:application)

    possible_names
  end

  def possible_process_titles_joined_regex
    possible_process_titles_joined_regex = ""
    possible_process_titles.each_with_index do |possible_name, index|
      possible_process_titles_joined_regex << "|" if index >= 1
      possible_process_titles_joined_regex << Regexp.escape(possible_name)
    end

    possible_process_titles_joined_regex
  end

  def present?(key)
    return true if options.key?(key) && options[key]

    false
  end

  def set(key, value)
    options[key] = value
  end
end
