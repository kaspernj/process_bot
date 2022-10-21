# ProcessBot

Run your app through ProcessBot for automatic restart if crashing, but still support normal deployment through Capistrano.

In the future ProcessBot will also watch memory usage and restart processes if leaking memory automatically and gracefully.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'process_bot'
```

Add to your `Capfile`:
```ruby
require "process_bot"
install_plugin ProcessBot::Capistrano::Sidekiq
install_plugin ProcessBot::Capistrano::Puma
```

Add to your `deploy.rb`:
```ruby
after "deploy:starting", "process_bot:sidekiq:graceful"
after "deploy:published", "process_bot:sidekiq:start"
after "deploy:failed", "process_bot:sidekiq:start"
```

## Usage

Run commands in the command line like this:

```bash
cap production process_bot:sidekiq:graceful
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspernj/process_bot.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
