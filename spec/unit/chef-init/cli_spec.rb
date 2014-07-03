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

require 'spec_helper'
require 'chef-init/cli'
require 'stringio'

describe ChefInit::CLI do
  let(:argv) { [] }
  let(:max_retries) { 5 }
  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  def stdout
    stdout_io.string
  end

  def stderr
    stderr_io.string
  end

  before do
    ChefInit::Log.stub(:info)

    # by default, we are running in local-mode
    File.stub(:exist?).with("/etc/chef/zero.rb").and_return(true)
  end

  subject(:cli) do
    ChefInit::CLI.new(argv, max_retries).tap do |c|
      c.stub(:stdout).and_return(stdout_io)
      c.stub(:stderr).and_return(stderr_io)
    end
  end

  describe "#run" do
    before do
      cli.stub(:launch_onboot)
      cli.stub(:launch_bootstrap)
    end

    it "should parse options" do
      expect(cli).to receive(:handle_options)
      cli.run
    end

    context "when onboot flag is passed" do
      let(:argv) { %w[ --onboot ] }

      it "should launch onboot steps" do
        expect(cli).to receive(:launch_onboot)
        cli.run
      end
    end

    context "when bootstrap flag is passed" do
      let(:argv) { %w[ --bootstrap ] }

      it "should launch build steps" do
        expect(cli).to receive(:launch_bootstrap)
        cli.run
      end
    end
  end

  describe "#handle_options" do
    context "default behavior" do
      let(:argv) { ["--bootstrap"] }

      it "should parse the input" do
        expect(cli).to receive(:parse_options).and_call_original
        cli.handle_options
      end

      it "should set default options" do
        expect(cli).to receive(:set_default_options)
        cli.handle_options
      end

      it "should set the log level" do
        expect(ChefInit::Log.level).to eql(:info)
        cli.handle_options
      end
    end

    context "version is requested" do
      let(:argv) { %w[ -v ] }
      let(:version_message) { "ChefInit Version: #{ChefInit::VERSION}\n" }

      it "should return the version number and then quit" do
        expect(cli).to receive(:exit).with(0)
        cli.handle_options
        expect(stdout).to eql(version_message)
      end
    end

    context "given no arguments or options" do
      let(:argv) { [] }
      it "alerts that you must pass in a flag or arguments" do
        expect(cli).to receive(:exit).with(1)
        cli.handle_options
        expect(stderr).to eql("You must pass in either the --onboot or --bootstrap flag.\n")
      end
    end

    context "given an invalid/unknown option" do
      it "gives an 'unknown option' message, the help output and exits with 1"
    end

    context "both bootstrap and onboot flags are given" do
      let(:argv) { %w[ --onboot --bootstrap ]}
      it "gives an 'invalid option' message, the help output and exits with 1" do
        expect(cli).to receive(:exit).with(1)
        cli.handle_options
        expect(stderr).to eql("You must pass in either the --onboot OR the --bootstrap flag, but not both.\n")
      end
    end

    context "local-mode config file already exists" do
      let(:argv) { %w[ --onboot ] }

      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(true)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
      end

      it "should default to local_mode" do
        expect(cli).to receive(:set_local_mode_defaults)
        expect(cli).not_to receive(:exit)
        cli.handle_options
      end
    end

    context "client-mode files already exists" do
      let(:argv) { %w[ --onboot ] }

      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
      end

      it "should default to client mode" do
        expect(cli).to receive(:set_server_mode_defaults)
        expect(cli).not_to receive(:exit)
        cli.handle_options
      end
    end
  end

  describe "#set_default_options" do
    context "zero.rb exists" do
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(true)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
      end

      it "sets local-mode defaults" do
        expect(cli).to receive(:set_local_mode_defaults)
        cli.set_default_options
      end
    end

    context "client.rb exists" do
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
      end

      it "sets client-mode defaults" do
        expect(cli).to receive(:set_server_mode_defaults)
        cli.set_default_options
      end
    end

    context "valid configuration file does not exist" do
      before do
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
      end

      it "should exit with error" do
        expect(cli).to receive(:exit).with(1)
        cli.set_default_options
        expect(stderr).to eql("Cannot find a valid configuration file in /etc/chef\n")
      end
    end
  end

  describe "#set_local_mode_defaults" do
    it "should set defaults typical for local-mode runs" do
      cli.set_local_mode_defaults
      expect(cli.config[:local_mode]).to eql(true)
      expect(cli.config[:config_file]).to eql("/etc/chef/zero.rb")
      expect(cli.config[:json_attribs]).to eql("/etc/chef/first-boot.json")
    end
  end

  describe "#set_server_mode_defaults" do
    it "should set defaults typical for client-mode runs" do
      cli.set_server_mode_defaults
      expect(cli.config[:local_mode]).to eql(false)
      expect(cli.config[:config_file]).to eql("/etc/chef/client.rb")
      expect(cli.config[:json_attribs]).to eql("/etc/chef/first-boot.json")
    end
  end

  describe "#launch_onboot" do
    let(:supervisor_pid) { 1000 }

    before do
      cli.stub(:print_welcome)
      cli.stub(:launch_supervisor).and_return(supervisor_pid)
      cli.stub(:wait_for_supervisor)
      cli.stub(:run_chef_client)
      cli.stub(:delete_validation_key)
      Process.stub(:wait)
    end

    it "prints a welcome message" do
      expect(cli).to receive(:print_welcome)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should launch process supervisor in non-blocking subprocess" do
      expect(cli).to receive(:launch_supervisor)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should wait for the supervisor to start" do
      expect(cli).to receive(:wait_for_supervisor)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should execute and wait for chef-client" do
      expect(cli).to receive(:run_chef_client)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should delete validation key when chef-client is finished" do
      expect(cli).to receive(:delete_validation_key)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should catch Kernel signals" do
      expect(Signal).to receive(:trap).with("TERM")
      expect(Signal).to receive(:trap).with("HUP")
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end

    it "should forward Kernel signals to supervisor process" do
      expect(Process).to receive(:kill).with("TERM", anything)
      pid1 = fork do
        cli.launch_onboot
      end
      Process.kill("TERM", pid1)

      expect(Process).to receive(:kill).with("HUP", anything)
      pid2 = fork do
        cli.launch_onboot
      end
      Process.kill("HUP", pid2)
    end

    it "should wait for supervisor to exit" do
      expect(Process).to receive(:wait).with(supervisor_pid)
      expect(cli).to receive(:exit).with(0)
      cli.launch_onboot
    end
  end

  describe "#launch_bootstrap" do
    let(:supervisor_pid) { 1000 }

    before do
      cli.stub(:print_welcome)
      cli.stub(:launch_supervisor).and_return(supervisor_pid)
      cli.stub(:wait_for_supervisor)
      cli.stub(:run_chef_client)
      cli.stub(:delete_client_key)
      Process.stub(:kill)
    end

    it "prints a welcome message" do
      expect(cli).to receive(:print_welcome)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end

    it "should launch process supervisor in non-blocking subprocess" do
      expect(cli).to receive(:launch_supervisor)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end

    it "should wait for the supervisor to start" do
      expect(cli).to receive(:wait_for_supervisor)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end

    it "should execute and wait for chef-client" do
      expect(cli).to receive(:run_chef_client)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end

    it "should delete the client key after chef-client is finished" do
      expect(cli).to receive(:delete_client_key)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end

    it "should kill the process supervisor when chef-client finishes" do
      expect(Process).to receive(:kill).with("TERM", supervisor_pid)
      expect(cli).to receive(:exit).with(0)
      cli.launch_bootstrap
    end
  end

  describe "#launch_supervisor" do
    let(:cmd) { "/opt/chef/embedded/bin/runsvdir -P /opt/chef/service 'log: #{ '.' * 395 }'" }
    let(:env) { {"PATH" => cli.path } }

    before do
      Process.stub(:spawn).with(env, cmd)
    end

    it "should launch supervisor as a non-block subprocess" do
      expect(Process).to receive(:spawn).with(env, cmd)
      cli.launch_supervisor
    end
  end

  describe "#wait_for_supervisor" do
    before do
      cli.stub(:sleep)
    end

    it "should sleep for 1 second" do
      expect(cli).to receive(:sleep).with(1)
      cli.wait_for_supervisor
    end
  end

  describe "#run_chef_client" do
    let(:env) { {"PATH" => cli.path } }

    before do
      Open3.stub(:popen2e)
    end

    context "when local-mode flag was passed in" do
      it "should execute chef-client in local-mode" do
        cli.stub(:chef_client_command) { "chef-client -c /etc/chef/zero.rb -j /etc/chef/first-boot.json -z" }
        expect(Open3).to receive(:popen2e).with(env, "chef-client -c /etc/chef/zero.rb -j /etc/chef/first-boot.json -z")
        cli.run_chef_client
      end
    end

    it "should execute chef-client" do
      cli.stub(:chef_client_command) { "chef-client -c /etc/chef/client.rb -j /etc/chef/first-boot.json" }
      expect(Open3).to receive(:popen2e).with(env, "chef-client -c /etc/chef/client.rb -j /etc/chef/first-boot.json")
      cli.run_chef_client
    end

    it "should forward stdout from subprocess to main stdout" do

    end
  end

  describe "#delete_validation_key" do
    before do
      File.stub(:exist?).with("/etc/chef/validation.pem").and_return(true)
      File.stub(:delete)
    end

    it "should remove validation key file" do
      expect(File).to receive(:delete).with("/etc/chef/validation.pem")
      cli.delete_validation_key
    end
  end

  describe "#delete_client_key" do
    before do
      File.stub(:exist?).with("/etc/chef/client.pem").and_return(true)
      File.stub(:delete)
    end

    it "should remove client key file" do
      expect(File).to receive(:delete).with("/etc/chef/client.pem")
      cli.delete_client_key
    end
  end

  describe "#chef_client_command" do
    context "chef local-mode" do
      let(:argv) { ["--bootstrap", "-z"]}
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(true)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
      end

      it "should return local-mode command" do
        cli.handle_options
        command = cli.chef_client_command
        expect(command).to eql("chef-client -c /etc/chef/zero.rb -j /etc/chef/first-boot.json -z -l info")
      end
    end

    context "environment is passed in" do
      let(:argv) { ["--bootstrap", "-E", "prod"] }
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
      end

      it "should pass through the environment variable" do
        cli.handle_options
        command = cli.chef_client_command
        expect(command).to eql("chef-client -c /etc/chef/client.rb -j /etc/chef/first-boot.json -l info -E prod")
      end
    end

    context "chef server-mode" do
      let(:argv) { ["--bootstrap"] }
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
      end

      it "should return server-mode command" do
        cli.handle_options
        command = cli.chef_client_command
        expect(command).to eql("chef-client -c /etc/chef/client.rb -j /etc/chef/first-boot.json -l info")
      end
    end
  end
end
