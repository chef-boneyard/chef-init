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
    allow(ChefInit::Log).to receive(:info)

    # by default, we are running in local-mode
    allow(File).to receive(:exist?).with('/etc/chef/zero.rb').and_return(true)
    allow(File).to receive(:exist?).with('/etc/chef/.node_name').and_return(false)
    allow(File).to receive(:exist?).with('/etc/chef/secure/validation.pem').and_return(true)
    allow(File).to receive(:exist?).with('/etc/chef/secure/client.pem').and_return(false)
  end

  subject(:cli) do
    ChefInit::CLI.new(argv, max_retries).tap do |c|
      allow(c).to receive(:stdout).and_return(stdout_io)
      allow(c).to receive(:stderr).and_return(stderr_io)
    end
  end

  describe '#run' do
    describe 'when onboot flag is passed' do
      let(:argv) { %w[ --onboot ] }
      before { cli.config[:onboot] = true }

      it 'parses parameters and sets default options, then runs onboot' do
        expect(cli).to receive(:parse_options).with(argv)
        expect(cli).to receive(:set_default_options)
        expect(cli).to receive(:launch_onboot)
        cli.run
      end
    end

    describe 'when bootstrap flag is passed' do
      let(:argv) { %w[ --bootstrap ] }
      before { cli.config[:bootstrap] = true }

      it 'parses parameters and sets default options, then runs onboot' do
        expect(cli).to receive(:parse_options).with(argv)
        expect(cli).to receive(:set_default_options)
        expect(cli).to receive(:launch_bootstrap)
        cli.run
      end
    end

    describe 'when given no arguments or options' do
      let(:argv) { [] }
      it 'alerts that you must pass in a flag or arguments' do
        expect(cli).to receive(:exit).with(false)
        cli.run
        expect(stderr).to eql('You must pass in either the --onboot, ' \
          "--bootstrap, --verify or --version flag.\n")
      end
    end

    describe 'when version flag is passed' do
      let(:argv) { %w[ -v ] }
      let(:version_message) { "ChefInit Version: #{ChefInit::VERSION}\n" }

      it 'returns the version number and then exits' do
        expect(cli).to receive(:exit).with(true)
        cli.run
        expect(stdout).to eql(version_message)
      end
    end

    describe 'when both bootstrap and onboot flags are given' do
      let(:argv) { %w[ --onboot --bootstrap ]}
      it 'gives an \'invalid option\' message, the help output and exits' do
        expect(cli).to receive(:exit).with(false)
        cli.run
        expect(stderr).to eql('You may pass in either the --onboot OR the ' \
          "--bootstrap flag but not both.\n")
      end
    end
  end

  describe '#set_default_options' do
    context 'when zero.rb exists' do
      before do
        allow(cli).to receive(:configured_for_local_mode?).and_return(true)
        allow(cli).to receive(:configured_for_server_mode?).and_return(false)
      end

      it 'sets local-mode defaults' do
        expect(cli).to receive(:validate_local_mode_config)
        expect(cli).to receive(:set_local_mode_defaults)
        cli.set_default_options
      end
    end

    context 'when client.rb exists' do
      before do
        allow(cli).to receive(:configured_for_local_mode?).and_return(false)
        allow(cli).to receive(:configured_for_server_mode?).and_return(true)
      end

      it 'sets client-mode defaults' do
        expect(cli).to receive(:validate_server_mode_config)
        expect(cli).to receive(:set_server_mode_defaults)
        cli.set_default_options
      end
    end

    context 'when valid configuration file does not exist' do
      before do
        allow(cli).to receive(:configured_for_local_mode?).and_return(false)
        allow(cli).to receive(:configured_for_server_mode?).and_return(false)
      end

      it 'exits with error' do
        expect(cli).to receive(:exit).with(false)
        cli.set_default_options
        expect(stderr).to eql("Cannot find a valid Chef configuration file in /etc/chef.\n")
      end
    end
  end

  describe '#launch_onboot' do
    let(:supervisor) { cli.supervisor }
    let(:chef_client) { cli.chef_client }
    
    it 'starts supervisor, runs chef-client, cleans up and waits' do
      expect(supervisor).to receive(:launch)
      expect(chef_client).to receive(:run)
      expect(cli).to receive(:delete_validation_key)
      expect(supervisor).to receive(:wait)
      expect(cli).to receive(:exit)
      cli.launch_onboot
    end
  end

  describe '#launch_bootstrap' do
    let(:exitcode) { 0 }
    let(:supervisor) { cli.supervisor }
    let(:chef_client) { cli.chef_client }
    before { allow(chef_client).to receive(:exit_code).and_return(exitcode) }

    it 'starts supervisor, runs chef-client, cleans up and exits' do
      expect(supervisor).to receive(:launch)
      expect(chef_client).to receive(:run)
      expect(cli).to receive(:delete_client_key)
      expect(cli).to receive(:delete_node_name_file)
      expect(cli).to receive(:empty_secure_directory)
      expect(supervisor).to receive(:shutdown)
      expect(cli).to receive(:exit).with(exitcode)
      cli.launch_bootstrap
    end

    context 'when --no-delete-secure is specified' do
      before { cli.config[:remove_secure] = false }

      it 'does not delete the secure directory' do
        expect(supervisor).to receive(:launch)
        expect(chef_client).to receive(:run)
        expect(cli).to receive(:delete_client_key)
        expect(cli).to receive(:delete_node_name_file)
        expect(cli).not_to receive(:empty_secure_directory)
        expect(supervisor).to receive(:shutdown)
        expect(cli).to receive(:exit).with(exitcode)
        cli.launch_bootstrap
      end
    end
  end
end
