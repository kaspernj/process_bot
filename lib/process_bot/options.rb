class ProcessBot::Options
  attr_reader :options

  def initialize(options = {})
    @options = options
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
