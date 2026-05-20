class ProcessBot::Options
  attr_reader :options

  def self.from_args(args)
    options = ProcessBot::Options.new

    args.each do |key, value|
      options.set(key, value)
    end

    options
  end

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
      event_handler.add_event(name: :on_log)
      event_handler.add_event(name: :on_process_started)
      event_handler.add_event(name: :on_socket_opened)
      event_handler
    end
  end

  def fetch(...)
    options.fetch(...)
  end

  def application_basename
    @application_basename ||= application_basename_from_release_path
  end

  def application_basename_from_release_path
    app_path_parts = release_path.split("/")
    deployment_marker_index = [
      app_path_parts.rindex("releases"),
      app_path_parts.rindex("current")
    ].compact.max

    return app_path_parts[0...deployment_marker_index].last if deployment_marker_index

    app_path_parts.last
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

  def release_path
    @release_path ||= fetch(:release_path)
  end

  def set(key, value)
    options[key] = value
  end
end
