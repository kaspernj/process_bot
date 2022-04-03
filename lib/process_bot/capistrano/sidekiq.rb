module ProcessBot::Capistrano::Sidekiq < Capistrano::Plugin
  include ProcessBot::Sidekiq::Helpers

  def define_tasks
    eval_rakefile File.expand_path("./sidekiq.rake", __FILE__)
  end
end
