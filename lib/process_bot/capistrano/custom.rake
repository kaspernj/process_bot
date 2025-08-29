git_plugin = self

namespace :process_bot do
  namespace :custom do
    desc "Stops the custom command"
    task :stop do
      git_plugin.process_bot_command(
        process_bot_data,
        :stop,
        "--handler" => "custom",
        "--name" => ENV.fetch("PROCESS_BOT_CUSTOM_ID")
      )
    end

    desc "Starts a custom command"
    task :start do
      git_plugin.process_bot_command(
        process_bot_data,
        :start,
        "--handler" => "custom",
        "--name" => ENV.fetch("PROCESS_BOT_CUSTOM_ID")
      )
    end

    desc "Restart a custom command"
    task :restart do
      invoke! "process_bot:custom:stop"
      invoke! "process_bot:custom:start"
    end
  end
end
