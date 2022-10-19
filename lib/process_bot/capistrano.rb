class ProcessBot::Capistrano
  autoload :Puma, "#{__dir__}/capistrano/puma"
  autoload :Sidekiq, "#{__dir__}/capistrano/sidekiq"
  autoload :SidekiqHelpers, "#{__dir__}/capistrano/sidekiq_helpers"
end
