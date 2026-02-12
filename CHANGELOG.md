## [Unreleased]
- Stop accepting new control commands during shutdown so in-flight responses complete reliably.
- Stream ProcessBot logs to connected control clients for Capistrano output.
- Sanitize broadcast log output to keep JSON encoding safe.
- Bump version to 0.1.20.
- Flush log output immediately so Capistrano can stream it.
- Bump version to 0.1.21.
- Add optional Sidekiq restart overlap and a new ProcessBot restart command.
- Guard stop-related process scanning when subprocess PID/PGID is unavailable and fail stop loudly.
- Wait briefly for subprocess PID assignment during stop; raise if PID is still missing so stop cannot silently succeed.

## [0.1.0] - 2022-04-03

- Initial release
