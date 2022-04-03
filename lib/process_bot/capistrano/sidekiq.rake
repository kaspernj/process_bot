git_plugin = self

namespace :load do
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
    # Rbenv, Chruby, and RVM integration
    set :rbenv_map_bins, fetch(:rbenv_map_bins).to_a.concat(%w[sidekiq sidekiqctl])
    set :rvm_map_bins, fetch(:rvm_map_bins).to_a.concat(%w[sidekiq sidekiqctl])
    set :chruby_map_bins, fetch(:chruby_map_bins).to_a.concat(%w[sidekiq sidekiqctl])
    # Bundler integration
    set :bundle_bins, fetch(:bundle_bins).to_a.concat(%w[sidekiq sidekiqctl])
    # Init system integration
    set :init_system, -> { nil }
    # systemd integration
    set :service_unit_name, "sidekiq-#{fetch(:stage)}.service"
    set :upstart_service_name, "sidekiq"
  end
end

namespace :process_bot do
  namespace :sidekiq do
    desc 'Quiet sidekiq (stop fetching new tasks from Redis)'
    task :quiet do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_sidekiq_processes.each do |sidekiq_process|
            git_plugin.stop_sidekiq(pid: sidekiq_process.fetch(:pid), signal: "TSTP")
          end
        end
      end
    end

    desc 'Stop sidekiq (graceful shutdown within timeout, put unfinished tasks back to Redis)'
    task :stop do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_sidekiq_processes.each do |sidekiq_process|
            git_plugin.stop_sidekiq(pid: sidekiq_process.fetch(:pid), signal: "TERM")
          end
        end
      end
    end

    task :stop_after_time do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          git_plugin.running_sidekiq_processes.each do |sidekiq_process|
            git_plugin.stop_sidekiq_after_time(pid: sidekiq_process.fetch(:pid), signal: "TERM")
          end
        end
      end
    end

    desc 'Start sidekiq'
    task :start do
      on roles fetch(:sidekiq_roles) do |role|
        git_plugin.switch_user(role) do
          fetch(:sidekiq_processes).times do |idx|
            puts "Starting Sidekiq #{idx}"
            git_plugin.start_sidekiq(idx)
          end
        end
      end
    end

    desc 'Restart sidekiq'
    task :restart do
      invoke! "process_bot:sidekiq:stop"
      invoke! "process_bot:sidekiq:start"
    end
  end
end
