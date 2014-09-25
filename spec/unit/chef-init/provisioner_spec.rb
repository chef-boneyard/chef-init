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
require 'chef-init/provisioner'

describe ChefInit::Provisioner do

  describe '#run' do
    let(:instance) { described_class.new }
    let(:provisioner) { ::ChildProcess.build('chef-client', *options)}
    let(:options) { ['-z', '--config', '/etc/chef/client.rb'] }
    let(:path) { '/opt/chef/bin' }

    before do
      allow(instance).to receive(:path).and_return(path)
    end

    it 'runs chef-client, waits for it to exit and then saves the exit code' do
      expect(::ChildProcess).to receive(:build).with('chef-client', '-z', '--config', '/etc/chef/client.rb').and_return(provisioner)
      expect(provisioner).to receive_message_chain(:io, :inherit!)
      expect(provisioner).to receive(:start)
      expect(provisioner).to receive(:wait)
      instance.run(options)
      expect(provisioner.leader).to eql(true)
      expect(provisioner.environment['PATH']).to eql(path)
    end
  end

  describe '#exit_code' do
    let(:instance) { described_class.new }
    let(:provisioner) { instance.provisioner }

    before do
      allow(provisioner).to receive(:exit_code).and_return(0)
    end

    it 'returns ChildProcess\' value for the exit code' do
      expect(instance.exit_code).to eql(0)
    end
  end
end
