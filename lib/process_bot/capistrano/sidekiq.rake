git_plugin = self

namespace :load do
  desc "Default variables for Sidekiq"
  task :defaults do
    set :sidekiq_default_hooks, true

    set :sidekiq_pid, -> { File.join(shared_path, "tmp", "pids", "sidekiq.pid") }
    set :sidekiq_env, -> { fetch(:rack_env, fetch(:rails_env, fetch(:stage))) }
    set :sidekiq_log, -> { File.join(shared_path, "log", "sidekiq.log") }
    set :sidekiq_timeout, 10
    set :sidekiq_roles, fetch(:sidekiq_role, :app)
    set :sidekiq_processes, 1
    set :sidekiq_options_per_process, nil
    set :sidekiq_user, nil
    set :process_bot_log, true
    # Rbenv, Chruby, and RVM integration
    set :rbenv_map_bins, fetch(:rbenv_map_bins).to_a + ["sidekiq", "sidekiqctl"]
    set :rvm_map_bins, fetch(:rvm_map_bins).to_a + ["sidekiq", "sidekiqctl"]
    set :chruby_map_bins, fetch(:chruby_map_bins).to_a + ["sidekiq", "sidekiqctl"]
    # Bundler integration
    set :bundle_bins, fetch(:bundle_bins).to_a + ["sidekiq", "sidekiqctl"]
  end
end

namespace :process_bot do
  namespace :sidekiq do
    desc "Stop Sidekiq and ProcessBot gracefully (stop fetching new tasks from Redis and then quit when nothing is running)"
    task :graceful do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_process_bot_processes.each do |process_bot_process|
            git_plugin.process_bot_command(process_bot_process, :graceful)
          end
        end
      end
    end

    desc "Stop Sidekiq and ProcessBot gracefully without waiting for completion"
    task :graceful_no_wait do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_process_bot_processes.each do |process_bot_process|
            git_plugin.process_bot_command(process_bot_process, :graceful_no_wait)
          end
        end
      end
    end

    desc "Stop Sidekiq and ProcessBot (graceful shutdown within timeout, put unfinished tasks back to Redis)"
    task :stop do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_process_bot_processes.each do |process_bot_data|
            git_plugin.process_bot_command(process_bot_data, :stop)
          end
        end
      end
    end

    desc "Start Sidekiq and ProcessBot"
    task :start do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          fetch(:sidekiq_processes).times do |idx|
            puts "Starting Sidekiq with ProcessBot #{idx}"
            git_plugin.start_sidekiq(idx)
          end
        end
      end
    end

    desc "Ensure the configured number of Sidekiq ProcessBots are running (excluding graceful shutdowns)"
    task :ensure_running do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          desired_processes = fetch(:sidekiq_processes).to_i
          running_processes = git_plugin.running_process_bot_processes

          graceful_processes = running_processes.select do |process_bot_data|
            git_plugin.sidekiq_process_graceful?(process_bot_data)
          end

          active_processes = running_processes - graceful_processes

          active_indexes = active_processes.filter_map do |process_bot_data|
            git_plugin.process_bot_sidekiq_index(process_bot_data)
          end

          graceful_indexes = graceful_processes.filter_map do |process_bot_data|
            git_plugin.process_bot_sidekiq_index(process_bot_data)
          end

          puts "ProcessBot Sidekiq in graceful shutdown: #{graceful_indexes.join(", ")}" if graceful_indexes.any?

          desired_indexes = (0...desired_processes).to_a
          missing_indexes = desired_indexes - active_indexes - graceful_indexes
          missing_count = desired_processes - active_indexes.count

          if missing_count.negative?
            puts "Found #{active_indexes.count} running ProcessBot Sidekiq processes; desired is #{desired_processes}"
            missing_count = 0
          end

          if missing_indexes.any?
            missing_indexes.each do |idx|
              puts "Starting Sidekiq with ProcessBot #{idx} (missing)"
              git_plugin.start_sidekiq(idx)
            end
          else
            puts "All ProcessBot Sidekiq processes are running (#{active_indexes.count}/#{desired_processes})"
          end

          return unless missing_count > missing_indexes.length

          puts "Skipped starting #{missing_count - missing_indexes.length} processes because " \
            "they are still in graceful shutdown"
        end
      end
    end

    desc "Restart Sidekiq and ProcessBot"
    task :restart do
      invoke! "process_bot:sidekiq:stop"
      invoke! "process_bot:sidekiq:start"
    end
  end
end
