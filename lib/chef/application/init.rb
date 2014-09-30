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

require 'chef/application'
require 'chef/config'
require 'chef/log'
require 'chef/config_fetcher'
require 'chef/handler/error_report'
require 'chef/workstation_config_loader'

require 'chef-init/config'
require 'chef-init/version'

#
# This is the main interface that you will interact with when launching a
# container. The CLI will accept various parameters and those parameters
# indicate the behavior you want happen when you launch the container.
#
# chef-init
#    chef-init without an option isthe primary PID1 that you will use. It will
#    launch the process supervisor and then run chef-client. It will then keep
#    the container alive until it receives the proper signal.
#
# chef-init --bootstrap
#    The +bootstrap+ parameter will run chef-client and then exit with the
#    exit status of the chef-client run. It is intended to be used inside a
#    Dockerfile as a RUN line. This command only be used as a PID1 if you want
#    the container to exit as soon as the chef-client run has completed.
#
# chef-init --version
#    The +version+ parameter will return the various versions of important
#    applications inside the container. Specifically, the version of chef-init
#    and chef-client.
#
# chef-init --verify
#    The +verify+ parameters will run the BATS tests the come with the Gem.
#    These tests should be used for functional testing.
#
class Chef::Application::Init < Chef::Application

  # Mimic self_pipe sleep from Unicorn to capture signals safely
  SELF_PIPE = []

  #
  # Action Options
  #
  option :bootstrap,
    long:         '--bootstrap',
    description:  'Run the chef client once and then exit with chef ' \
                      'client\'s exit status.',
    boolean:      true

  option :verify,
    long:         '--verify',
    description:  'Run integration tests to verify installation was successful',
    boolean:      true,
    proc:         lambda {|v|
      test_dir = File.expand_path(File.join(__FILE__, "../../..", 'tests'))
      ::Kernel.exec("bats #{test_dir}/local_bootstrap.bats")
    }

  option :run_chef_client,
    long:         '--[no-]chef-client',
    description:  'Run the Chef Client when chef-init starts. Default is true.',
    boolean:      true

  option :version,
    short:        '-v',
    long:         '--version',
    description:  'Display the versions of the relevant Chef components',
    boolean:      true,
    proc:         lambda {|v|
      puts "Chef: #{::Chef::VERSION}"
      puts "ChefInit:: #{::ChefInit::VERSION}"
    },
    exit:         0

  option :help,
    short:        "-h",
    long:         "--help",
    description:  "Show this message",
    on:           :tail,
    boolean:      true,
    show_options: true,
    exit:         0

  #
  # Chef Container-specific options
  #
  option :remove_secure_directory,
    long:         '--[no-]remove-secure',
    description:  'Do not remove secure credentials (validation key, encrypted ' \
                      'data bag secret, etc) from image.',
    boolean:      true

  option :secure_directory,
    long:         '--secure-directory DIRECTORY',
    description:  'The directory where secure credentials can be found.'

  option :supervisor_pid_file,
    long:         '--supervisor-pid PIDFILE',
    description:  'Set the PID file location, defaults to /tmp/supervisor.pid'

  #
  # Chef Client related options
  #
  option :config_file,
    short:        "-c CONFIG",
    long:         "--config CONFIG",
    description:  "The configuration file to use"

  option :log_level,
    short:        "-l LEVEL",
    long:         "--log_level LEVEL",
    description:  "Set the log level (debug, info, warn, error, fatal)",
    proc:         lambda { |l| l.to_sym }

  option :log_location,
    short:        "-L LOGLOCATION",
    long:         "--logfile LOGLOCATION",
    description:  "Set the log file location, defaults to STDOUT - recommended for daemonizing",
    proc:         nil

  option :node_name,
    short:        "-N NODE_NAME",
    long:         "--node-name NODE_NAME",
    description:  "The node name for this client",
    proc:         nil

  option :validation_key,
    short:        "-K KEY_FILE",
    long:         "--validation_key KEY_FILE",
    description:  "Set the validation key file location, used for registering new clients",
    proc:         nil

  option :client_key,
    short:        "-k KEY_FILE",
    long:         "--client_key KEY_FILE",
    description:  "Set the client key file location",
    proc:         nil


  SHUTDOWN_SIGNAL = "1".freeze
  SHUTDOWN_REMOVE_CLIENT_SIGNAL = "2".freeze
  RUN_CHEF_CLIENT = "3".freeze

  def setup_signal_handlers
    unless Chef::Platform.windows?
      SELF_PIPE.replace IO.pipe

      trap("USR1") do
        Chef::Log.info("Received SIGUSR1 - running chef-client")
        SELF_PIPE[1].putc(RUN_CHEF_CLIENT)
      end

      trap("USR2") do
        Chef::Log.info("Received SIGUSR2 - removing artifacts from Chef Server and shutting down")
        SELF_PIPE[1].putc(SHUTDOWN_REMOVE_CLIENT_SIGNAL)
      end

      trap("INT") do
        Chef::Log.info("Received SIGINT - shutting down")
        SELF_PIPE[1].putc(SHUTDOWN_SIGNAL)
      end

      trap("TERM") do
        puts "got TERM"
        Chef::Log.info("Received SIGTERM - shutting down")
        SELF_PIPE[1].putc(SHUTDOWN_SIGNAL)
      end
    end
  end

  def load_config_file
    if !config.has_key?(:config_file) && !config[:disable_config]
      if config[:local_mode]
        config[:config_file] = Chef::WorkstationConfigLoader.new(nil, Chef::Log).config_location
      else
        config[:config_file] = Chef::Config.platform_specific_path("/etc/chef/client.rb")
      end
    end
    super
  end

  def reconfigure
    super
    Chef::Config[:node_name] ||= ENV['CHEF_NODE_NAME']
  end

  def run_application
    start_supervisor

    if Chef::Config[:bootstrap]
      bootstrap_node
    elsif Chef::Config[:run_chef_client]
      run_chef_client
    end

    loop do
      begin
        signal = pause_for_signal

        # Handle incoming signals
        exit!('Shutting down', 0) if signal == SHUTDOWN_SIGNAL
        clean_and_exit!('Shutting down', 0) if signal == SHUTDOWN_REMOVE_CLIENT_SIGNAL
        run_chef_client if signal == RUN_CHEF_CLIENT
      # rescue SystemExit => e
      #   # Catch exits and make sure to cleanly shutdown
      #   exit!("#{e.class}: #{e.message}", e.status)
      rescue Exception => e
        # Catch a chef-client run error
        fatal!("#{e.class}: #{e.message}", 1)
      end
    end
  end

  #
  # This is a special chef-client run that runs the chef-client only once and
  # then cleans up the chef server artifacts before exiting.
  #
  def bootstrap_node
    shell_out!("chef-client #{ARGV.clone.join(' ')} --once")
    delete_client_key
    empty_secure_directory if Chef::Config[:remove_secure_directory]
    SELF_PIPE[1].putc(SHUTDOWN_REMOVE_CLIENT_SIGNAL)
  rescue Mixlib::ShellOut::ShellCommandFailed => e
    clean_and_exit!(e.message, 1)
  end

  #
  # Run the chef-client by either
  #   a) sending a daemonized chef-client the USR1 signal
  #   b) spawning a chef-client process
  #
  def run_chef_client
    if File.exist?(Chef::Config[:pid_file])
      ::Process.kill('USR1', ::File.read(config[:pid_file]).to_i)
    else
      pid = ::Process.spawn("chef-client #{ARGV.clone.join(' ')}")
      ::Process.detach(pid)
      sleep 1 until ::File.exist?(Chef::Config[:client_key])
      delete_validation_key
    end
  end

  #
  # Delete the contents of the secure directory
  #
  def empty_secure_directory
    ::FileUtils.rm_rf("#{Chef::Config[:secure_directory]}/.", secure: true)
  end

  #
  # Delete the client key
  #
  def delete_client_key
    ::File.delete(Chef::Config[:client_key]) if ::File.exist?(Chef::Config[:client_key])
  end

  #
  # Delete the valdiation key.
  #
  def delete_validation_key
    ::File.delete(Chef::Config[:validation_key]) if ::File.exist?(Chef::Config[:validation_key]) && ::File.exist?(Chef::Config[:client_key])
  end

  #
  # Extracted from Chef::Knife.delete_object, because it has a
  # confirmation step built in. By specifying the USR1 signal they
  # are agreeing to delete it.
  #
  def destroy_item(klass, name, type_name)
    begin
      object = klass.load(name)
      object.destroy
      Chef::Log.info("Deleted #{type_name} #{name}")
    rescue Net::HTTPServerException
      Chef::Log.warn("Could not find a #{type_name} named #{name} to delete!")
    end
  end

  #
  # Spawn the supervisor process and save the PID to a file.
  #
  def start_supervisor
    Chef::Log.info('Starting Supervisor')
    supervisor_pid = ::Process.spawn(Chef::Config[:supervisor_start_command])
    ::File.open(config[:supervisor_pid_file], 'w+') {|f| f.puts supervisor_pid }
    Chef::Log.info("Supervisor pid: #{supervisor_pid}")
  end

  #
  # Shutdown the supervisor process based on the PID that was saved
  # during the start
  #
  def shutdown_supervisor
    supervisor_pid = ::File.read(config[:supervisor_pid_file]).to_i
    ::Process.kill('HUP', supervisor_pid)
    ::Process.wait supervisor_pid
    ::FileUtils.rm_rf(config[:supervisor_pid_file])
  rescue SystemCallError => e
    # This will be reached if the supervisor is already dead
  end

  #
  # Sleep for 1 second and grab any signals in SELF_PIPE. Returns the signal or nil
  #
  def pause_for_signal
    ::IO.select([ SELF_PIPE[0] ], nil, nil, 1) or return
    SELF_PIPE[0].getc.chr
  end

  #
  # Cleanup the node and client objects before exiting
  #
  # @param [String] msg
  #   The message to log just before exiting
  # @param [Fixnum] err
  #   The exit code to return
  #
  def clean_and_exit!(msg, err = -1)
    destroy_item(Chef::Node, Chef::Config[:node_name], 'node')
    destroy_item(Chef::ApiClient, Chef::Config[:node_name], 'client')
    exit!(msg, err)
  end

  #
  # Shutdown the supervisor process before fatally exiting
  #
  def fatal!(msg, err = -1)
    shutdown_supervisor
    Chef::Application.fatal!(msg, err)
  end

  #
  # Shutdown the supervisor process before exiting normally
  #
  def exit!(msg, err = -1)
    shutdown_supervisor
    Chef::Application.exit!(msg, err)
  end
end
