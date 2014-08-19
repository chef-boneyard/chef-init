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
    File.stub(:exist?).with("/etc/chef/.node_name").and_return(false)
    File.stub(:exist?).with("/etc/chef/secure/validation.pem").and_return(true)
    File.stub(:exist?).with("/etc/chef/secure/client.pem").and_return(false)
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

    describe "when the application starts" do
      let(:argv) { %w[ --version ] }

      it "parses the input" do
        expect(cli).to receive(:parse_options).and_call_original
        expect(cli).to receive(:exit).with(true)
        cli.run
      end
    end

    describe "when onboot flag is passed" do
      let(:argv) { %w[ --onboot ] }

      it "sets default options" do
        expect(cli).to receive(:set_default_options)
        cli.run
      end

      it "launches onboot steps" do
        expect(cli).to receive(:launch_onboot)
        cli.run
      end
    end

    describe "when bootstrap flag is passed" do
      let(:argv) { %w[ --bootstrap ] }

      it "sets default options" do
        expect(cli).to receive(:set_default_options)
        cli.run
      end

      it "launches build steps" do
        expect(cli).to receive(:launch_bootstrap)
        cli.run
      end
    end

    describe "when verify flag is passed" do
      let(:argv) { %w[ --verify ] }
      let(:verify) { double("ChefInit::Verify", run: nil) }

      it "runs the verification process" do
        ChefInit::Verify.stub(:new).and_return(verify)
        expect(verify).to receive(:run)
        cli.run
      end
    end

    describe "when given no arguments or options" do
      let(:argv) { [] }
      it "alerts that you must pass in a flag or arguments" do
        expect(cli).to receive(:exit).with(false)
        cli.run
        expect(stderr).to eql("You must pass in either the --onboot, " \
          "--bootstrap, or --verify flag.\n")
      end
    end

    describe "when version flas is passes" do
      let(:argv) { %w[ -v ] }
      let(:version_message) { "ChefInit Version: #{ChefInit::VERSION}\n" }

      it "returns the version number and then exits" do
        expect(cli).to receive(:exit).with(true)
        cli.run
        expect(stdout).to eql(version_message)
      end
    end

    describe "when both bootstrap and onboot flags are given" do
      let(:argv) { %w[ --onboot --bootstrap ]}
      it "gives an 'invalid option' message, the help output and exits" do
        expect(cli).to receive(:exit).with(false)
        cli.run
        expect(stderr).to eql("You must pass in either the --onboot OR the " \
          "--bootstrap flag, but not both.\n")
      end
    end

  end

  describe "#set_default_options" do
    context "when zero.rb exists" do
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(true)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
      end

      it "sets local-mode defaults" do
        expect(cli).to receive(:set_local_mode_defaults)
        cli.set_default_options
      end
    end

    context "when client.rb exists" do
      before do
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
      end

      it "sets client-mode defaults" do
        expect(cli).to receive(:set_server_mode_defaults)
        cli.set_default_options
      end

      context "with missing validator and client keys" do
        before do
          File.stub(:exist?).with("/etc/chef/client.rb").and_return(true)
          File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
          File.stub(:exist?).with("/etc/chef/secure/validation.pem").and_return(false)
          File.stub(:exist?).with("/etc/chef/secure/client.pem").and_return(false)
        end

        it "errors out and prints a message" do
          expect(cli).to receive(:exit).with(false)
          cli.set_default_options
          expect(stderr).to eql("File /etc/chef/secure/validator.pem is missing." \
            " Please make sure your secure credentials are accessible" \
            " to the running container.\n")
        end
      end
    end

    context "when valid configuration file does not exist" do
      before do
        File.stub(:exist?).with("/etc/chef/client.rb").and_return(false)
        File.stub(:exist?).with("/etc/chef/zero.rb").and_return(false)
      end

      it "exits with error" do
        expect(cli).to receive(:exit).with(false)
        cli.set_default_options
        expect(stderr).to eql("Cannot find a valid configuration file in /etc/chef\n")
      end
    end
  end

  describe "#set_local_mode_defaults" do
    before { cli.set_local_mode_defaults }

    it 'sets local mode to true' do
      expect(cli.config[:local_mode]).to eql(true)
    end

    it 'uses zero.rb for the config file' do
      expect(cli.config[:config_file]).to eql("/etc/chef/zero.rb")
    end

    it 'uses first-boot.json for json attributes' do
      expect(cli.config[:json_attribs]).to eql("/etc/chef/first-boot.json")
    end
  end

  describe "#set_server_mode_defaults" do
    before { cli.set_server_mode_defaults }

    it 'sets local mode to false' do
      expect(cli.config[:local_mode]).to eql(false)
    end

    it 'uses client.rb for the config file' do
      expect(cli.config[:config_file]).to eql("/etc/chef/client.rb")
    end

    it 'uses first-boot.json for json attributes' do
      expect(cli.config[:json_attribs]).to eql("/etc/chef/first-boot.json")
    end
  end

  describe "#launch_onboot" do
    let(:supervisor_pid) { 1000 }
    let(:chefrun_pid) { 1001 }

    before do
      cli.stub(:launch_supervisor).and_return(supervisor_pid)
      cli.stub(:wait_for_supervisor)
      cli.stub(:run_chef_client).and_return(chefrun_pid)
      cli.stub(:delete_validation_key)
      Process.stub(:wait).with(supervisor_pid)
      Process.stub(:wait).with(chefrun_pid)
    end

    it "launches process supervisor" do
      expect(cli).to receive(:launch_supervisor)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it "waits for the supervisor to start" do
      expect(cli).to receive(:wait_for_supervisor).and_return(supervisor_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it "executes chef-client" do
      expect(cli).to receive(:run_chef_client).and_return(chefrun_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it 'waits for chef-client to finish' do
      expect(Process).to receive(:wait).with(chefrun_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it "deletes validation key when chef-client is finished" do
      expect(cli).to receive(:delete_validation_key)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it "catches SIGTERM and SIGKILL to shutdown supervisor" do
      expect(cli).to receive(:trap).with("TERM")
      expect(cli).to receive(:trap).with("KILL")
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end

    it "waits for supervisor to exit" do
      expect(Process).to receive(:wait).with(supervisor_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_onboot
    end
  end

  describe "#launch_bootstrap" do
    let(:supervisor_pid) { 1000 }
    let(:chefrun_pid) { 1001 }

    before do
      cli.stub(:launch_supervisor).and_return(supervisor_pid)
      cli.stub(:wait_for_supervisor)
      cli.stub(:run_chef_client).and_return(chefrun_pid)
      cli.stub(:delete_client_key)
      cli.stub(:delete_node_name_file)
      cli.stub(:shutdown_supervisor)
      cli.stub(:empty_secure_directory)
      Process.stub(:wait).with(supervisor_pid)
      Process.stub(:wait).with(chefrun_pid)
      cli.stub(:kill)
    end

    it "launches the process supervisor" do
      expect(cli).to receive(:launch_supervisor).and_return(supervisor_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "waits for the supervisor to start" do
      expect(cli).to receive(:wait_for_supervisor)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "executes and wait for chef-client" do
      expect(cli).to receive(:run_chef_client).and_return(chefrun_pid)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "deletes the client key after chef-client is finished" do
      expect(cli).to receive(:delete_client_key)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "deletes the node name file if it exists" do
      expect(cli).to receive(:delete_node_name_file)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "shuts down the supervisor" do
      expect(cli).to receive(:shutdown_supervisor)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    it "deletes the secure directory" do
      expect(cli).to receive(:empty_secure_directory)
      expect(cli).to receive(:exit).with(true)
      cli.launch_bootstrap
    end

    context "when --no-delete-secure is specified" do
      before { cli.config[:remove_secure] = false }
      it "does not delete the secure directory" do
        expect(cli).not_to receive(:empty_secure_directory)
        expect(cli).to receive(:exit).with(true)
        cli.launch_bootstrap
      end
    end

  end

  describe "#launch_supervisor" do
    it "should launch supervisor as a non-blocking subprocess" do
      expect(cli).to receive(:fork) do |&block|
        expect(cli).to receive(:exec).with(
          {"PATH" => cli.path},
          "/opt/chef/embedded/bin/runsvdir",
          "-P",
          "/opt/chef/service",
          "'log: #{ '.' * 395}'"
        )
        block.call
      end
      cli.launch_supervisor
    end
  end

  describe "#run_chef_client" do
    before { cli.stub(:chef_client_command).and_return("chef-client") }

    it "executes chef-client as a non-blocking sub-process" do
      expect(cli).to receive(:fork) do |&block|
        expect(cli).to receive(:exec).with(
          {"PATH" => cli.path},
          "chef-client"
        )
        block.call
      end
      cli.run_chef_client
    end
  end

  describe "#chef_client_command" do

    describe "with local-mode defaults" do
      before do
        cli.config[:local_mode] = true
        cli.config[:config_file] = "/etc/chef/zero.rb"
        cli.config[:json_attribs] = "/etc/chef/first-boot.json"
        cli.config[:log_level] = :info
      end

      it { expect(cli.send(:chef_client_command)).to eql("chef-client -c " \
        "/etc/chef/zero.rb -j /etc/chef/first-boot.json -l info -z") }
    end

    describe "with server-mode defaults" do
      before do
        cli.config[:local_mode] = false
        cli.config[:config_file] = "/etc/chef/client.rb"
        cli.config[:json_attribs] = "/etc/chef/first-boot.json"
        cli.config[:log_level] = :info
      end

      it { expect(cli.send(:chef_client_command)).to eql("chef-client -c " \
        "/etc/chef/client.rb -j /etc/chef/first-boot.json -l info") }
    end

    describe "with environment specified" do
      before do
        cli.config[:local_mode] = true
        cli.config[:config_file] = "/etc/chef/zero.rb"
        cli.config[:json_attribs] = "/etc/chef/first-boot.json"
        cli.config[:log_level] = :info
        cli.config[:environment] = "prod"
      end

      it { expect(cli.send(:chef_client_command)).to eql("chef-client -c " \
        "/etc/chef/zero.rb -j /etc/chef/first-boot.json -l info -z -E prod")}
    end
  end
end
