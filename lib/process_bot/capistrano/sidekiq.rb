class ProcessBot::Capistrano::Sidekiq < Capistrano::Plugin
  include ProcessBot::Capistrano::SidekiqHelpers

  def define_tasks
    eval_rakefile File.expand_path("./sidekiq.rake", __dir__)
  end
end
