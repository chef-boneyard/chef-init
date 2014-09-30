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
require 'chef/application/init'

describe Chef::Application::Init do

  describe '#reconfigure' do
    before do
      allow(Kernel).to receive(:trap).and_return(:ok)
      @original_argv = ARGV.dup
      ARGV.clear
    end

    subject(:chef_init) do
      Chef::Application::Init.new.tap do |init|
        allow(init).to receive(:trap)
        allow(init).to receive(:configure_opt_parser).and_return(true)
        allow(init).to receive(:configure_chef).and_return(true)
        allow(init).to receive(:configure_logging).and_return(true)
        init.cli_arguments = []
      end
    end

    after { ARGV.replace(@original_argv) }

    it 'accepts a node name via environment variable' do
      ENV['CHEF_NODE_NAME'] = "env_value"
      chef_init.reconfigure
      expect(Chef::Config[:node_name]).to eql("env_value")
    end
  end

  describe '#run_application' do
    let(:pipe) { IO.pipe }

    before do
      Chef::Config[:node_name] = 'rspector'
      Chef::Config[:run_chef_client] = false
      @pipe = IO.pipe

      chef_init.setup_signal_handlers
      allow(chef_init).to receive(:start_supervisor) { @pipe[1].puts 'Starting Supervisor' }
      allow(chef_init).to receive(:shutdown_supervisor) { @pipe[1].puts 'Stopping Supervisor' }
      allow(chef_init).to receive(:bootstrap_node) { @pipe[1].puts 'Bootstrapping Node' }
      allow(chef_init).to receive(:run_chef_client) { @pipe[1].puts 'Running Chef Client' }
      allow(chef_init).to receive(:destroy_item) do |klass, name, type_name|
        @pipe[1].puts "Removing #{type_name} #{name} of type #{klass}"
      end
    end

    let(:chef_init) { Chef::Application::Init.new }

    context 'when it receives SIGTERM' do
      it 'exits gracefully' do
        pid = fork do
          chef_init.run_application
        end

        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Starting Supervisor\n")
        ::Process.kill('TERM', pid)
        ::Process.wait(pid)
        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Stopping Supervisor\n")
      end
    end

    context 'when it receives SIGINT' do
      it 'exits gracefully' do
        pid = fork do
          chef_init.run_application
        end

        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Starting Supervisor\n")
        ::Process.kill('INT', pid)
        ::Process.wait(pid)
        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Stopping Supervisor\n")
      end
    end

    context 'when it receives SIGUSR1' do
      it 'tells chef-client to run' do
        pid = fork do
          chef_init.run_application
        end

        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Starting Supervisor\n")
        ::Process.kill('USR1', pid)
        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Running Chef Client\n")
        ::Process.kill('TERM', pid)
        ::Process.wait(pid)
      end
    end

    context 'when it receives SIGUSR2' do
      it 'removes artifacts from the chef server before exiting gracefully' do
        pid = fork do
          chef_init.run_application
        end

        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Starting Supervisor\n")
        ::Process.kill('SIGUSR2', pid)
        ::Process.wait(pid)
        expect(IO.select([@pipe[0]], nil, nil, 1)).to_not be_nil
        expect(@pipe[0].gets).to eql("Removing node rspector of type Chef::Node\n")
        expect(@pipe[0].gets).to eql("Removing client rspector of type Chef::ApiClient\n")
        expect(@pipe[0].gets).to eql("Stopping Supervisor\n")
      end
    end
  end

end
