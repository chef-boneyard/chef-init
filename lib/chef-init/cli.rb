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
require 'chef-init/verify'
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

    option :verify,
      :long         => "--verify",
      :description  => "Verify installation",
      :boolean      => true

    option :log_level,
      :short        => "-l LEVEL",
      :long         => "--log_level LEVEL",
      :description  => "Set the log level (debug, info, warn, error, fatal)",
      :default      => "info"

    option :environment,
      :short        => "-E ENVIRONMENT",
      :long         => "--environment",
      :description  => "Set the Chef Environment on the node"

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
      parse_options(@argv)
      ChefInit::Log.level = config[:log_level].to_sym

      case
      when config[:version]
        msg "ChefInit Version: #{ChefInit::VERSION}"
        exit 0
      when config[:onboot] && config[:bootstrap]
          err "You must pass in either the --onboot OR the --bootstrap flag, but not both."
          exit 1
      when config[:onboot]
        set_default_options
        launch_onboot
      when config[:bootstrap]
        set_default_options
        launch_bootstrap
      when config[:verify]
        verify = ChefInit::Verify.new
        verify.run
      else
        err "You must pass in either the --onboot, --bootstrap, or --verify flag."
        exit 1
      end
    end

    def set_default_options
      if File.exist?("/etc/chef/zero.rb") || (config.key?(:config_file) && config[:config_file].match(/^.*zero\.rb$/)) || config[:local_mode]
        set_local_mode_defaults
      elsif File.exist?("/etc/chef/client.rb") || (config.key?(:config_file) && config[:config_file].match(/^.*client\.rb$/))
        unless (File.exist?("/etc/chef/secure/validation.pem") || File.exist?("/etc/chef/secure/client.pem"))
          err "File /etc/chef/secure/validator.pem is missing. Please make sure your secure credentials are accessible to the running container."
          exit 1
        end
        set_server_mode_defaults
      else
        err "Cannot find a valid configuration file in /etc/chef"
        exit 1
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
      delete_node_name_file

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
        wait_thr.pid
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
      File.delete("/etc/chef/secure/client.pem") if File.exist?("/etc/chef/secure/client.pem")
    end

    def delete_node_name_file
      File.delete("/etc/chef/.node_name") if File.exist?("/etc/chef/.node_name")
    end

    def delete_validation_key
      File.delete("/etc/chef/secure/validation.pem") if File.exist?("/etc/chef/secure/validation.pem")
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
