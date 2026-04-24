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
- Always run RuboCop against changed or created Ruby files.
- Added `graceful_no_wait` command and Capistrano task for non-blocking graceful shutdowns.
- Always add or update tests for new/changed functionality, and run them.
- Added coverage for graceful_no_wait and Capistrano wait defaults.
- Bumped version to 0.1.20 for log streaming updates.

## Release policy
- Do not bump the version in `lib/process_bot/version.rb` (and do not touch the `process_bot (x.y.z)` line in `Gemfile.lock`) as part of a feature or fix PR.
- Version bumps, CHANGELOG version headings, and the rubygems push are driven by the release rake tasks (`bundle exec rake release:patch`, `release:minor`, or `release:major`), run by the release maintainer after the PR lands on master.
- PRs should land their code change and add CHANGELOG notes under the `## [Unreleased]` heading only. Leave version numbers to the release workflow.
