require 'chef-init/version'
require 'chef-init/helpers'
require 'mixlib/cli'
require 'open3'

module ChefInit
  class CLI
    include Mixlib::CLI
    include ChefInit::Helpers

    attr_reader :argv
    attr_reader :max_retries
    attr_reader :supervisor

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

    option :bootstrap,
      :long => "--bootstrap",
      :description => "",
      :boolean => true,
      :default => false

    option :onboot,
      :long => "--onboot",
      :description => "",
      :boolean => true,
      :default => false

    option :log_level,
      :short        => "-l LEVEL",
      :long         => "--log_level LEVEL",
      :description  => "Set the log level (debug, info, warn, error, fatal)",
      :default      => "info"

    def initialize(argv, max_retries=5)
      @argv = argv
      @max_retries = max_retries
      super()
    end

    def run
      handle_options

      if config[:onboot]
        launch_onboot
      elsif config[:bootstrap]
        launch_bootstrap
      end
    end

    ##
    # Configuration Methods
    #
    def handle_options
      parse_options(argv)
      set_default_options

      unless config[:onboot] || config[:bootstrap]
        err "You must pass in either the --onboot OR the --bootstrap flag."
        exit 1
      end

      if config[:onboot] && config[:bootstrap]
        err "You must pass in either the --onboot OR --bootstrap flag, but not both." 
        exit 1
      end

      ChefInit::Log.level = config[:log_level].to_sym
    end

    def set_default_options
      if ::File.exist?("/chef/zero.rb")
        set_local_mode_defaults
      elsif ::File.exist?("/etc/chef/client.rb")
        set_server_mode_defaults
      end
    end

    def set_local_mode_defaults
      config[:local_mode] ||= true
      config[:config_file] ||= "/chef/zero.rb"
      config[:json_attribs] ||= "/chef/first-boot.json"
    end

    def set_server_mode_defaults
      config[:local_mode] ||= false
      config[:config_file] ||= "/etc/chef/client.rb"
      config[:json_attribs] ||= "/etc/chef/first-boot.json"
    end

    ##
    # Launch onboot
    #
    def launch_onboot
      print_welcome

      ChefInit::Log.info("Starting Supervisor...")
      @supervisor = launch_supervisor
      ChefInit::Log.info("Supervisor pid: #{@supervisor}")

      ChefInit::Log.info("Waiting for Supervisor to start...")
      wait_for_supervisor

      ChefInit::Log.info("Starting chef-client run...")
      run_chef_client

      # Catch TERM signal and foward to supervisor
      Signal.trap("TERM") do
        ChefInit::Log.info("Received SIGTERM - shutting down supervisor...\n\nGoodbye!")
        Process.kill("TERM", @supervisor)
      end

      # Catch HUP signal and forward to supervisor
      Signal.trap("HUP") do
        ChefInit::Log.info("Received SIGHUP - shutting down supervisor...\n\nGoodbye!")
        Process.kill("HUP", @supervisor)
      end

      # Wait for supervisor to quit
      ChefInit::Log.info("Waiting for Supervisor to exit...")
      Process.wait(@supervisor)
      exit 0
    end
    
    ##
    # Launch bootstrap
    #
    def launch_bootstrap
      print_welcome

      ChefInit::Log.info("Starting Supervisor...")
      @supervisor = launch_supervisor
      ChefInit::Log.info("Supervisor pid: #{@supervisor}")

      ChefInit::Log.info("Waiting for Supervisor to start...")
      wait_for_supervisor

      ChefInit::Log.info("Starting chef-client run...\n")
      run_chef_client

      Process.kill("TERM", @supervisor)
      exit 0
    end

    def launch_supervisor
      Process.spawn({"PATH" => path}, supervisor_launch_command)
    end

    def wait_for_supervisor
      sleep 1
    end

    def supervisor_launch_command
      "#{omnibus_embedded_bin_dir}/runsvdir -P #{omnibus_root}/service 'log: #{ '.' * 395}'"
    end

    def run_chef_client 
      ::Open3.popen2e({"PATH" => path}, chef_client_command) do |_i,oe,_t|
        oe.each { |line| puts line }
      end
    end

    def path
      "#{omnibus_root}/bin:#{omnibus_root}/embedded/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
    end

    def chef_client_command
      if config[:local_mode]
        "chef-client -c #{config[:config_file]} -j #{config[:json_attribs]} -z -l #{config[:log_level]}"
      else
        "chef-client -c #{config[:config_file]} -j #{config[:json_attribs]} -l #{config[:log_level]}"
      end
    end

    ##
    # Logging
    #
    def print_welcome
      puts <<-eos

#################################
# Welcome to Chef Container
#################################

      eos
    end
  end
end
