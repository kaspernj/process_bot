# ProcessBot

Run your app through ProcessBot for automatic restart if crashing, but still support normal deployment through Capistrano.

Watch memory usage for Sidekiq and restart gracefully if it exceeds a given limit (to counter memory leaks).

When deploying can gracefully exit Sidekiq to let long running jobs finish on old version of code, and start new Sidekiq processes after finishing deploy (but still let the old ones finish gracefully so nothing gets interrupted).
This requires not to remove columns, rename columns or any other intrusive database changes.

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

You can also skip waiting for graceful completion:

```bash
cap production process_bot:sidekiq:graceful_no_wait
```

### Logging

ProcessBot can log its internal actions (connecting, sending commands, signals, etc.) to stdout.
Enable this with `--log true` (or `--logging true`):

```bash
bundle exec process_bot --command start --log true
bundle exec process_bot --command graceful --log true
bundle exec process_bot --command graceful_no_wait --log true
```

To write logs to a file, add `--log-file-path`:

```bash
bundle exec process_bot --command start --log true --log-file-path /var/log/process_bot.log
```

### Graceful shutdown waiting

ProcessBot can wait for graceful shutdowns to finish, but this is optional.
In Capistrano deploys the default is to continue immediately while Sidekiq finishes in the background.
To wait for completion, set:

```ruby
set :process_bot_wait_for_gracefully_stopped, true
```

If you want both behaviors, use `process_bot:sidekiq:graceful` (wait) and
`process_bot:sidekiq:graceful_no_wait` (no wait).

### Capistrano logging

ProcessBot logging is enabled by default in the Capistrano integration.
You can override it with:

```ruby
set :process_bot_log, false
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspernj/process_bot.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
