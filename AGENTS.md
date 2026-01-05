# AGENTS

## Notes
- Added an internal logging toggle via `--log`/`--logging` and routed internal actions through the logger.
- Added log lines for client connections, command sends, and signal handling.
- Documented logging usage in `README.md`.
- Branch: logging-toggle
- PR: https://github.com/kaspernj/process_bot/pull/164
- Made graceful shutdown waiting optional and defaulted Capistrano to not wait.
- Kept graceful handling synchronous and verified `bundle exec rspec`.
- Enabled ProcessBot logging by default for Capistrano hooks (configurable via `process_bot_log`).
