class ProcessBot::Capistrano::Puma < Capistrano::Plugin
  include ::Capistrano::PumaCommon

  def register_hooks
    after "deploy:finished", "process_bot:puma:smart_restart"
  end

  def define_tasks
    eval_rakefile File.expand_path("./puma.rake", __dir__)
  end

  def puma_running?
    backend.test("[ -f #{fetch(:puma_pid)} ]") && backend.test(:kill, "-0 $( cat #{fetch(:puma_pid)} )")
  end

  def run_puma_command(command)
    backend.execute :pumactl, "--control-url 'tcp://127.0.0.1:9293'", "--control-token foobar", "-F #{fetch(:puma_conf)} #{command}"
  end

  def stop_puma
    run_puma_command("stop")
  end
end
