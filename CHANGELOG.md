## [Unreleased]
- Stop accepting new control commands during shutdown so in-flight responses complete reliably.
- Stream ProcessBot logs to connected control clients for Capistrano output.
- Sanitize broadcast log output to keep JSON encoding safe.
- Bump version to 0.1.20.
- Flush log output immediately so Capistrano can stream it.
- Bump version to 0.1.21.
- Add optional Sidekiq restart overlap and a new ProcessBot restart command.
- Guard stop-related process scanning when subprocess PID/PGID is unavailable and fail stop loudly.
- Skip custom stop-related process scanning when no subprocess PID has been recorded, while still raising when a known PID has no PGID.

## [0.1.0] - 2022-04-03

- Initial release
