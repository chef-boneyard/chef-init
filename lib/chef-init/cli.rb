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

    option :remove_secure,
      :long         => "--[no-]remove-secure",
      :description  => "Remove secure credentials from image.",
      :boolean      => true,
      :default      => true

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
      @terminated_child_processes = {}
      @monitor_child_processes = []
      super()
    end

    def run
      parse_options(@argv)
      ChefInit::Log.level = config[:log_level].to_sym

      case
      when config[:version]
        msg "ChefInit Version: #{ChefInit::VERSION}"
        exit true
      when config[:onboot] && config[:bootstrap]
        err "You must pass in either the --onboot OR the --bootstrap flag, but not both."
        exit false
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
        exit false
      end
    end

    def set_default_options
      if File.exist?("/etc/chef/zero.rb") || (config.key?(:config_file) &&
          config[:config_file].match(/^.*zero\.rb$/)) || config[:local_mode]
        set_local_mode_defaults
      elsif File.exist?("/etc/chef/client.rb") || (config.key?(:config_file) &&
          config[:config_file].match(/^.*client\.rb$/))
        unless (File.exist?("/etc/chef/secure/validation.pem") ||
            File.exist?("/etc/chef/secure/client.pem"))
          err "File /etc/chef/secure/validator.pem is missing. Please make " \
            "sure your secure credentials are accessible to the running container."
          exit false
        end
        set_server_mode_defaults
      else
        err "Cannot find a valid configuration file in /etc/chef"
        exit false
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
      # Catch SIGKILL
      trap("KILL") do
        ChefInit::Log.info("Received SIGKILL - shutting down supervisor")
        shutdown_supervisor
      end

      # Catch SIGTERM
      trap("TERM") do
        ChefInit::Log.info("Received SIGTERM - shutting down supervisor")
        shutdown_supervisor
      end

      ChefInit::Log.info("Starting Supervisor...")
      @supervisor = launch_supervisor
      @monitor_child_processes << @supervisor
      ChefInit::Log.info("Supervisor pid: #{@supervisor}")

      ChefInit::Log.debug("Waiting for Supervisor to start...")
      wait_for_supervisor

      ChefInit::Log.info("Starting chef-client run...")
      @chef_client = run_chef_client
      @monitor_child_processes << @chef_client
      waitpid_reap_other_children(@chef_client)

      ChefInit::Log.debug("Deleting validation key")
      delete_validation_key

      waitpid_reap_other_children(@supervisor)

      exit true
    end

    ##
    # Launch bootstrap
    #
    def launch_bootstrap
      ChefInit::Log.info("Starting Supervisor...")
      @supervisor = launch_supervisor
      ChefInit::Log.info("Supervisor pid: #{@supervisor}")

      ChefInit::Log.debug("Waiting for Supervisor to start...")
      wait_for_supervisor

      ChefInit::Log.info("Starting chef-client run...")
      @chef_client = run_chef_client
      @monitor_child_processes << @chef_client
      chef_client_exitstatus = waitpid_reap_other_children(@chef_client) == 0

      ChefInit::Log.info("Deleting client key...")
      delete_client_key
      ChefInit::Log.debug("Removing node name file...")
      delete_node_name_file
      ChefInit::Log.info("Emptying secure folder...")
      empty_secure_directory if config[:remove_secure]

      shutdown_supervisor

      exit chef_client_exitstatus
    end

    #
    # Launch the supervisor
    #
    def launch_supervisor
      fork do
        exec({"PATH" => path}, supervisor_launch_command)
      end
    end

    #
    # Run the chef-client
    #
    def run_chef_client
      fork do
        exec({"PATH" => path}, chef_client_command)
      end
    end

    def shutdown_supervisor
      ChefInit::Log.debug("Waiting for services to stop...")

      ChefInit::Log.debug("Exit all the services")
      system_command("#{omnibus_embedded_bin_dir}/sv stop #{omnibus_root}/service/*")
      system_command("#{omnibus_embedded_bin_dir}/sv exit #{omnibus_root}/service/*")

      ChefInit::Log.debug("Kill the primary supervisor")
      Process.kill("HUP", @supervisor)
      sleep 3
      Process.kill("TERM", @supervisor)
      sleep 3
      Process.kill("KILL", @supervisor)

      ChefInit::Log.debug("Kill the runsv processes")
      get_all_services.each do |die_daemon_die|
        system_command("pkill -KILL -f 'runsv #{die_daemon_die}'")
      end

      ChefInit::Log.debug("Shutdown complete...")
    end

    def chef_client_command
      command = ["chef-client"]
      command << "-c #{config[:config_file]}"
      command << "-j #{config[:json_attribs]}"
      command << "-l #{config[:log_level]}"

      if config[:local_mode]
        command << "-z"
      end

      unless config[:environment].nil?
        command << "-E #{config[:environment]}"
      end

      command.join(" ")
    end

    private

    # Waits for the child process with the given PID, while at the same time
    # reaping any other child processes that have exited (e.g. adopted child
    # processes that have terminated).
    # (code from https://github.com/phusion/baseimage-docker translated from python)
    def waitpid_reap_other_children(pid)
      if @terminated_child_processes.include?(pid)
        # A previous call to waitpid_reap_other_children(),
        # with an argument not equal to the current argument,
        # already waited for this process. Return the status
        # that was obtained back then.
        return @terminated_child_processes.delete(pid)
      end
      done = false
      status = nil
      until done
        begin
          this_pid, status = Process.wait2(-1, 0)
          if this_pid == pid
            done = true
          elsif @monitor_child_processes.include?(pid)
            @terminated_child_processes[this_pid] = status
          end
        rescue Errno::ECHILD, Errno::ESRCH
          return
        end
      end
      status
    end

    def wait_for_supervisor
      sleep 5
    end

    def supervisor_launch_command
      "#{omnibus_embedded_bin_dir}/runsvdir -P #{omnibus_root}/service 'log: #{ '.' * 395}'"
    end

    def empty_secure_directory
      FileUtils.rm_rf("/etc/chef/secure/.", secure: true)
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

    def get_all_services_files
      Dir[File.join("#{omnibus_root}/service", '*')]
    end

    def get_all_services
      get_all_services_files.map { |f| File.basename(f) }.sort
    end
  end
end
