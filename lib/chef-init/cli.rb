#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
    attr_reader :chef_client

    option :config_file,
      :short        => "-c CONFIG",
      :long         => "--config",
      :description  => "The configuration file to use"

    option :json_attribs,
      :short        => "-j JSON_ATTRIBS",
      :long         => "--json-attributes",
      :description  => "Load attributes from a JSON file or URL"

    option :local_mode,
      :short        => "-z",
      :long         => "--local-mode",
      :description  => "Point chef-client at local repository",
      :boolean      => true

    option :bootstrap,
      :long         => "--bootstrap",
      :description  => "",
      :boolean      => true,
      :default      => false

    option :onboot,
      :long         => "--onboot",
      :description  => "",
      :boolean      => true,
      :default      => false

    option :log_level,
      :short        => "-l LEVEL",
      :long         => "--log_level LEVEL",
      :description  => "Set the log level (debug, info, warn, error, fatal)",
      :default      => "info"

    option :environment,
      :short        => "-E ENVRIONMENT",
      :long         => "--environment",
      :description  => "Set the Chef Environment on the node"

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

    option :version,
      :short        => "-v",
      :long         => "--version",
      :boolean      => true

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
      parse_options(@argv)
      set_default_options

      if config[:version]
        msg "ChefInit Version: #{ChefInit::VERSION}"
        exit 0
      else
        unless config[:onboot] || config[:bootstrap] || !cli_arguments.empty?
          err "You must pass in either the --onboot or --bootstrap flag."
          exit 1
        end

        if config[:onboot] && config[:bootstrap]
          err "You must pass in either the --onboot OR the --bootstrap flag, but not both."
          exit 1
        end

        ChefInit::Log.level = config[:log_level].to_sym
      end
    end

    def set_default_options
      if ::File.exist?("/etc/chef/zero.rb") || config[:local_mode]
        set_local_mode_defaults
      elsif ::File.exist?("/etc/chef/client.rb")
        set_server_mode_defaults
      end
    end

    def set_local_mode_defaults
      config[:local_mode] ||= true
      config[:config_file] ||= "/etc/chef/zero.rb"
      config[:json_attribs] ||= "/etc/chef/first-boot.json"
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
      @chef_client = run_chef_client

      ChefInit::Log.debug("Wait for chef-client to finish, then delete validation key")
      Process.wait(@chef_client)
      delete_validation_key

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

      ChefInit::Log.info("Starting chef-client run...")
      run_chef_client

      ChefInit::Log.info("Deleting client key...")
      delete_client_key

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
      Open3.popen2e({"PATH" => path}, chef_client_command) do |stdin, stdout_err, wait_thr|
        while line = stdout_err.gets
          puts line
        end
        wait_thr.value.to_i
      end
    end

    def path
      "#{omnibus_root}/bin:#{omnibus_root}/embedded/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
    end

    def chef_client_command
      command = []
      command << "chef-client -c #{config[:config_file]} -j #{config[:json_attribs]}"

      if config[:local_mode]
        command << "-z"
      end

      command << "-l #{config[:log_level]}"

      unless config[:environment].nil?
        command << "-E #{config[:environment]}"
      end

      command.join(" ")
    end

    def delete_client_key
      File.delete("/etc/chef/client.pem") if File.exists?("/etc/chef/client.pem")
    end

    def delete_validation_key
      File.delete("/etc/chef/validation.pem") if File.exists?("/etc/chef/validation.pem")
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
