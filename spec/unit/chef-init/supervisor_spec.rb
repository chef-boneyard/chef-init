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
require 'chef-init/supervisor'

describe ChefInit::Supervisor do

  describe '#new' do
    let(:supervisor) { double('Supervisor') }
    it 'creates a new ChildProcess object' do
      expect(::ChildProcess).to receive(:build)
        .with('/opt/chef/embedded/bin/runsvdir', '-P', '/opt/chef/service')
        .and_return(supervisor)
      instance = described_class.new
      expect(instance.supervisor).to eql(supervisor)
    end
  end

  describe '#launch' do
    subject(:instance) { described_class.new }
    let(:supervisor) { instance.supervisor }

    it 'configures environment and starts process' do
      allow(instance).to receive(:path).and_return('/opt/chef/bin')
      expect(supervisor.io).to receive(:inherit!)
      expect(supervisor).to receive(:start)
      instance.launch
      expect(supervisor.leader).to eql(true)
      expect(supervisor.environment['PATH']).to eql('/opt/chef/bin')
    end
  end

  describe '#wait' do
    let(:instance) { described_class.new }
    let(:supervisor) { instance.supervisor}

    it 'pauses until the process finishes' do
      expect(supervisor).to receive(:wait)
      instance.wait
    end

    context 'when Errno::ECHILD is raised' do
      before { allow(supervisor).to receive(:wait).and_raise(Errno::ECHILD) }
      it 'does not bork' do
        expect { instance.wait }.not_to raise_error

      end
    end
  end

  describe '#shutdown' do
    let(:instance) { described_class.new }
    let(:supervisor) { instance.supervisor}

    before do
      allow(supervisor).to receive(:pid).and_return(100)
      allow(instance).to receive(:system_command)
    end

    it 'gracefully stops supervisor and all child processes' do
      expect(instance).to receive(:system_command).with('/opt/chef/embedded/bin/sv stop /opt/chef/service/*')
      expect(instance).to receive(:system_command).with('/opt/chef/embedded/bin/sv exit /opt/chef/service/*')
      expect(::Process).to receive(:kill).with('HUP', 100)
      expect(supervisor).to receive(:poll_for_exit).with(10)
      instance.shutdown
    end

    context 'supervisor doesnt stop within 10 seconds' do
      before do
        allow(::Process).to receive(:kill)
        allow(instance).to receive(:system_command)
        allow(supervisor).to receive(:poll_for_exit).and_raise(ChildProcess::TimeoutError)
      end

      it 'force stops the supervisor' do
        expect(supervisor).to receive(:stop)
        instance.shutdown
      end
    end
  end



end
