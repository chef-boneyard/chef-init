require 'chef-init/version'
require 'chef-init/helpers'
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

    option :provision,
      :long => "--provision",
      :description => "",
      :boolean => true,
      :default => false

    option :onboot,
      :long => "--onboot",
      :description => "",
      :boolean => true,
      :default => false

    def initialize(argv, max_retries=5)
      @argv = argv
      @max_retries = max_retries
      super()
    end

    def run
      handle_options

      if config[:onboot]
        launch_onboot
      elsif config[:provision]
        launch_provision
      end
    end

    ##
    # Configuration Methods
    #
    def handle_options
      parse_options(argv)
      set_default_options

      unless config[:onboot] || config[:provision]
        err "You must pass in either the --onboot OR the --provision flag."
        exit 1
      end

      if config[:onboot] && config[:provision]
        err "You must pass in either the --onboot OR --provision flag, but not both." 
        exit 1
      end
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

      supervisor = launch_supervisor

      wait_for_supervisor

      run_chef_client

      # Catch TERM signal and foward to supervisor
      Signal.trap("TERM") do
        Process.kill("TERM", supervisor)
      end

      # Catch HUP signal and forward to supervisor
      Signal.trap("HUP") do
        Process.kill("HUP", supervisor)
      end

      # Wait for supervisor to quit
      Process.wait(supervisor)
      exit $?.exitstatus
    end
    
    ##
    # Launch build
    #
    def launch_provision
      supervisor = launch_supervisor

      wait_for_supervisor

      run_chef_client

      Process.kill("TERM", supervisor)
      exit 0
    end

    def launch_supervisor
      Process.spawn(supervisor_launch_command)
    end

    def wait_for_supervisor
      sleep 1
    end

    def supervisor_launch_command
      "#{omnibus_embedded_bin_dir}/runsvdir -P #{omnibus_root}/service 'log: #{ '.' * 395}'"
    end

    def run_chef_client 
      Open3.popen2e(chef_client_command) do |_i,oe,_t|
        oe.each { |line| puts line }
      end
    end

    def chef_client_command
      if config[:local_mode]
        "chef-client -c #{config[:config_file]} -j #{config[:json_attribs]} -z"
      else
        "chef-client -c #{config[:config_file]} -j #{config[:json_attribs]}"
      end
    end
  end
end
