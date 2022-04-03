class ProcessBot::Capistrano
  autoload :Puma, "#{__dir__}/capistrano/puma"
  autoload :Sidekiq, "#{__dir__}/capistrano/sidekiq"
end
