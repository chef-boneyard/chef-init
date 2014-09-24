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
require 'childprocess'
require 'mixlib/cli'

module ChefInit
  #
  # This is the main interface that you will interact with when launching a
  # container. The CLI will accept various parameters and those parameters
  # indicate the behavior you want happen when you launch the container.
  #
  # chef-init --version
  #    The +version+ parameter will return the various versions of important
  #    applications inside the container. Specifically, the version of chef-init
  #    and chef-client.
  #
  # chef-init --bootstrap
  #    The +bootstrap+ parameter will run chef-client and then exit with the
  #    exit status of the chef-client run. It is intended to be used inside a
  #    Dockerfile as a RUN line. This command only be used as a PID1 if you want
  #    the container to exit as soon as the chef-client run has completed.
  #
  # chef-init --onboot
  #    The +onboot+ parameter is the primary PID1 that you will use. It will
  #    launch the process supervisor and then run chef-client. It will then keep
  #    the container alive until it receives the proper SIGNAL.
  #
  # chef-init --verify
  #    The +verify+ parameters will run the BATS tests the come with the Gem.
  #    These tests should be used for functional testing. 
  #
  class CLI
    include Mixlib::CLI
    include ChefInit::Helpers

    attr_reader :argv
    attr_reader :max_retries
    attr_reader :supervisor
    attr_reader :chef_client

    #
    # Action Options
    #
    option :bootstrap,
      long:         '--bootstrap',
      description:  'Run the chef client once and then exit with chef ' \
                        'client\'s exit status.',
      boolean:      true,
      default:      false

    option :onboot,
      long:         '--onboot',
      description:  'Run the chef client once and then keep alive until a ' \
                        'POSIX signal is received.',
      boolean:      true,
      default:      false

    option :verify,
      long:         '--verify',
      description:  'Run integration tests to verify installation was successful',
      boolean:      true,
      default:      false

    option :version,
      short:        '-v',
      long:         '--version',
      description:  'Display the versions of the relevant Chef components.',
      boolean:      true

    #
    # Chef Container-specific options
    #
    option :remove_secure,
      long:         '--[no-]remove-secure',
      description:  'Do not remove secure credentials (validation key, encrypted ' \
                        'data bag secret, etc) from image.',
      boolean:      true,
      default:      true

    #
    # Chef Client related options
    #
    option :config_file,
      short:        '-c CONFIG',
      long:         '--config',
      description:  'The Chef configuration file to use instead of the ' \
                        'default (/etc/chef/{client,zero}.rb).'

    option :json_attribs,
      short:        '-j JSON_ATTRIBS',
      long:         '--json-attributes',
      description:  'Load node attributes from a JSON file or URL.'

    option :local_mode,
      short:        '-z',
      long:         '--local-mode',
      description:  'Run the chef client in local mode (do not connect to ' \
                        ' chef server).',
      boolean:      true

    option :log_level,
      short:        '-l LEVEL',
      long:         '--log_level LEVEL',
      description:  'Set the log level (debug, info, warn, error, fatal).',
      default:      'info'

    option :environment,
      short:        '-E ENVIRONMENT',
      long:         '--environment ENVIRONMENT',
      description:  'Set the Chef Environment for the container node.'


    #
    # Creates a new CLI object
    #
    # @param [Array] argv
    #   The command line parameters and arguments passed in via the CLI
    # @param [Fixnum] max_retries
    #   The number of attempts that should be made for various internal tasks
    #   before giving up.
    #
    def initialize(argv, max_retries=5)
      @argv = argv
      @max_retries = max_retries
      super()
    end

    #
    # Accepts in the ARGV arguments and runs the primary chef-init application.
    #
    def run
      parse_options(@argv)
      ChefInit::Log.level = config[:log_level].to_sym

      case
      when config[:version]
        msg "ChefInit Version: #{ChefInit::VERSION}"
        exit true
      when config[:onboot] && config[:bootstrap]
        err 'You may pass in either the --onboot OR the --bootstrap ' \
            'flag but not both.'
        exit false
      when config[:onboot]
        set_default_options
        launch_onboot
      when config[:bootstrap]
        set_default_options
        launch_bootstrap
      when config[:verify]
        run_verification
      else
        err 'You must pass in either the --onboot, --bootstrap, --verify ' \
            'or --version flag.'
        exit false
      end
    end

    #
    # Evaluate the state of the system to determine whether the we should
    # connect to and run against a Chef Server or if we are running in
    # local mode.
    #
    # If a valid configuration file (client.rb or zero.rb) we will print
    # an error message and exit with a non-zero exit code.
    #
    def set_default_options
      case
      when configured_for_local_mode?
        validate_local_mode_config
        set_local_mode_defaults
      when configured_for_server_mode?
        validate_server_mode_config
        set_server_mode_defaults
      else
        err 'Cannot find a valid Chef configuration file in /etc/chef.'
        exit false
      end
    end

    #
    # Launch the process supervisor and run chef client. Wait until POSIX
    # signals are received which indicate that PID1 should be shutdown.
    # When that happens, tell the supervisor to shutdown all the processes
    # it is responsible for. After that happens, exit with 0.
    #
    def launch_onboot
      trap("KILL") do
        ChefInit::Log.info("Received SIGKILL - shutting down supervisor")
        shutdown_supervisor
      end

      trap("TERM") do
        ChefInit::Log.info("Received SIGTERM - shutting down supervisor")
        shutdown_supervisor
      end

      ChefInit::Log.info("Starting Supervisor...")
      launch_supervisor

      ChefInit::Log.info("Starting chef-client run...")
      run_chef_client

      ChefInit::Log.info("Deleting validation key")
      delete_validation_key

      wait_for_supervisor

      exit true
    end

    #
    # Launch the process supervisor and execute a chef client run. Once
    # the chef client run has completed, exit the main process with the
    # exit status of the chef client run.
    #
    def launch_bootstrap
      ChefInit::Log.info("Starting Supervisor...")
      launch_supervisor

      ChefInit::Log.info("Starting chef-client run...")
      ccr_exit_code = run_chef_client

      ChefInit::Log.info("Deleting client key...")
      delete_client_key
      ChefInit::Log.info("Removing node name file...")
      delete_node_name_file
      ChefInit::Log.info("Emptying secure folder...")
      empty_secure_directory if config[:remove_secure]

      shutdown_supervisor

      exit ccr_exit_code
    end

    #
    # Run the BATS tests that come with chef-init.
    #
    def run_verification
      # Grab path to directory where tests are kept
      tests_dir = File.expand_path(File.join(__FILE__, "../../..", 'tests'))

      # Execute the tests
      test_suite = system_command(
        "bats #{tests_dir}/local_bootstrap.bats",
        timeout: 120,
        live_stream: stdout,
        env: { 'PATH' => path }
      )
      test_suite.error!
      exit test_suite.exitstatus
    end

    private

    #
    # Returns whether or not the the system has the neccesary files to run
    # the chef client in local mode.
    #
    # @return [Boolean]
    #
    def configured_for_local_mode?
      File.exist?('/etc/chef/zero.rb') ||
      (config.key?(:config_file) && config[:config_file].match(/^.*zero\.rb$/)) ||
      config[:local_mode]
    end

    #
    # Validate that the components neccesary to run the chef-client in local
    # mode exist. If they do not, print an error message and exit with a non-zero
    # exit code.
    #
    def validate_local_mode_config
    end

    #
    # Set various config options with the local mode values.
    #
    def set_local_mode_defaults
      config[:local_mode] ||= true
      config[:config_file] ||= '/etc/chef/zero.rb'
      config[:json_attribs] ||= '/etc/chef/first-boot.json'
    end

    #
    # Returns whether or not the the system has the neccesary files to connect
    # to a chef server and run the chef-client in server mode.
    #
    # @return [Boolean]
    #
    def configured_for_server_mode?
      File.exist?('/etc/chef/client.rb') ||
      (config.key?(:config_file) && config[:config_file].match(/^.*client\.rb$/))
    end

    #
    # Validate that the components neccesary to run the chef-client in server
    # mode exist. If they do not, print an error message and exit with a non-zero
    # exit code.
    #
    def validate_server_mode_config
      unless (File.exist?('/etc/chef/secure/validation.pem') ||
              File.exist?('/etc/chef/secure/client.pem'))
        err 'File /etc/chef/secure/validator.pem is missing. Please make ' \
          'sure your secure credentials are accessible to the running container.'
        exit false
      end
    end

    #
    # Set various config options with the server mode values.
    #
    def set_server_mode_defaults
      config[:local_mode] ||= false
      config[:config_file] ||= '/etc/chef/client.rb'
      config[:json_attribs] ||= '/etc/chef/first-boot.json'
    end

    #
    # Creates and returns a ChildProcess object for the Supervisor
    #
    # @return [ChildProcess]
    #
    def launch_supervisor
      process = ::ChildProcess.build(supervisor_launch_command)
      process.io.inherit!
      process.leader = true
      process.start
      process
    end

    #
    # Returns the command to use to launch the process supervisor.
    #
    # @return [String]
    #
    def supervisor_launch_command
      [
        "#{omnibus_embedded_bin_dir}/runsvdir",
        "-P", "#{omnibus_root}/service",
        "'log: #{ '.' * 395}'"
      ]
    end

    #
    # Wait for the Supervisor to exit
    #
    def wait_for_supervisor
      @supervisor.wait
    end

    #
    # Shuts down the supervisor process as well as all the processes
    # that the supervisor is responsible for.
    #
    def shutdown_supervisor
      ChefInit::Log.debug("Waiting for services to stop...")

      ChefInit::Log.debug("Exit all the services")
      system_command("#{omnibus_embedded_bin_dir}/sv stop #{omnibus_root}/service/*")
      system_command("#{omnibus_embedded_bin_dir}/sv exit #{omnibus_root}/service/*")

      ChefInit::Log.debug("Kill the primary supervisor")
      @supervisor.stop

      ChefInit::Log.debug("Shutdown complete...")
    end

    #
    # Run the chef-client
    #
    def run_chef_client
      ccr = system_command(chef_client_command)
      ccr.exitstatus
    end

    #
    # Returns the proper chef client command to use when running chef-client.
    # This value is calculated based on the options that were passed in to the
    # CLI.
    #
    # @return [String]
    #
    def chef_client_command
      command = ['chef-client']
      command << "-c #{config[:config_file]}"
      command << "-j #{config[:json_attribs]}"
      command << "-l #{config[:log_level]}"

      if config[:local_mode]
        command << '-z'
      end

      unless config[:environment].nil?
        command << "-E #{config[:environment]}"
      end

      command.join(' ')
    end

    #
    # Delete the contents of the secure directory
    #
    def empty_secure_directory
      FileUtils.rm_rf("/etc/chef/secure/.", secure: true)
    end

    #
    # Delete the client key
    #
    def delete_client_key
      File.delete('/etc/chef/secure/client.pem') if File.exist?('/etc/chef/secure/client.pem')
    end

    #
    # Delete the .node_name file
    #
    def delete_node_name_file
      File.delete('/etc/chef/.node_name') if File.exist?('/etc/chef/.node_name')
    end

    #
    # Delete the valdiation key.
    #
    def delete_validation_key
      File.delete('/etc/chef/secure/validation.pem') if File.exist?('/etc/chef/secure/validation.pem')
    end

    #
    # Returns a list of all the services that the process supervisor
    # is currently responsible for.
    #
    # @return [Array#String]
    #
    def get_all_services_files
      Dir[File.join("#{omnibus_root}/service", '*')]
    end

    #
    # Returns an array with the fully-qualified paths to all the
    # service folders that the process supervisor is currently
    # responsible for.
    #
    # @return [Array#String]
    #
    def get_all_services
      get_all_services_files.map { |f| File.basename(f) }.sort
    end
  end
end
