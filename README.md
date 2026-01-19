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

### Capistrano tasks

ProcessBot provides these Sidekiq tasks:
- `process_bot:sidekiq:start`
- `process_bot:sidekiq:stop`
- `process_bot:sidekiq:graceful` (stops fetching new jobs and waits for running jobs by default)
- `process_bot:sidekiq:graceful_no_wait` (stops fetching new jobs and returns immediately)
- `process_bot:sidekiq:ensure_running` (starts missing processes, including replacements for graceful shutdowns)
- `process_bot:sidekiq:restart`

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

Use `process_bot:sidekiq:graceful` to wait for running jobs, and
`process_bot:sidekiq:graceful_no_wait` to return immediately while Sidekiq drains.

### Overlapping restarts

You can restart Sidekiq while the old process drains by enabling overlap on the ProcessBot instance:

```ruby
set :sidekiq_restart_overlap, true
```

When enabled, `process_bot:sidekiq:restart` will use the overlap behavior.

Or when running ProcessBot directly:

```bash
bundle exec process_bot --command restart --sidekiq-restart-overlap true
```

### Capistrano logging

ProcessBot logging is enabled by default in the Capistrano integration.
You can override it with:

```ruby
set :process_bot_log, false
```

### CLI options

When running ProcessBot directly, you can control graceful waiting and log file output:

```bash
bundle exec process_bot --command graceful_no_wait
bundle exec process_bot --command start --log-file-path /var/log/process_bot.log
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspernj/process_bot.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
