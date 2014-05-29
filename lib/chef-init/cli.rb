require 'chef-init/version'
require 'chef-init/chef_runner'
require 'chef-init/helpers'
require 'chef/dsl/container_service'
require 'mixlib/cli'

module ChefInit
  class CLI
    include Mixlib::CLI
    include ChefInit::Helpers

    attr_reader :argv
    attr_reader :max_retries

    option :config_file,
      :short => "-c CONFIG",
      :long => "--config",
      :description => "The configuration file to use"

    option :json_attribs,
      :short => "-j JSON_ATTRIBS",
      :long => "--json-attributes",
      :description => "Load attributes from a JSON file or URL"

    option :local_mode,
      :short => "-z",
      :long => "--local-mode",
      :description => "Point chef-client at local repository",
      :boolean => true

    option :build,
      :long => "--build",
      :description => "Gracefully kill process supervisor after successful chef-client run",
      :boolean => true,
      :default => false

    def initialize(argv, max_retries=5)
      @argv = argv
      @max_retries = max_retries
      super()
    end

    def run
      handle_options

      parent_pid = Process.pid

      fork do
        wait_for_runit
        run_chef_client
        Process.kill("HUP", parent_pid) if config[:build]
      end

      launch_runsvdir
    end

    #
    # Configuration Methods
    #
    def handle_options
      parse_options(argv)
      set_default_options
    end

    def set_default_options
      if config[:local_mode]
        set_local_mode_defaults
      else
        set_server_mode_defaults
      end
    end

    def set_local_mode_defaults
      config[:config_file] ||= "/chef/zero.rb"
      config[:json_attribs] ||= "/chef/first-boot.json" if File.exists?("/chef/first-boot.json")
    end

    def set_server_mode_defaults
      config[:config_file] ||= "/etc/chef/client.rb"
      config[:json_attribs] ||= "/etc/chef/first-boot.json" if File.exists?("/etc/chef/first-boot.json")
    end

    #
    # Runit Methods
    #
    def wait_for_runit
      tries = 0
      begin 
        tries += 1
        supervisor_running?("runsvdi[r]")
      rescue ChefInit::Exceptions::ProcessSupervisorNotRunning
        if (tries < @max_retries)
          sleep(2**tries)
          retry
        else
          exit 1
        end
      end
    end

    def launch_runsvdir
      exec("#{omnibus_embedded_bin_dir}/runsvdir -P #{omnibus_root}/service 'log: #{ '.' * 395}'")
    end

    #
    # Chef Methods
    #
    def run_chef_client
      chef_runner.converge
    end

    def chef_runner
      @chef_runner ||= ChefRunner.new(config[:config_file], config[:json_attribs], config[:local_mode])
    end


    # The last character in the process_name should have brackets around it
    # so that it doesn't find the grep process itself. 
    #
    # example: runsvdi[r]
    def supervisor_running?(process_name) 
      cmd = system_command("ps aux | grep #{process_name}")
      running = (cmd.stdout =~ /runsvdir/ && cmd.exitstatus == 0)
      raise ChefInit::Exceptions::ProcessSupervisorNotRunning unless running
      running
    end
  end
end
