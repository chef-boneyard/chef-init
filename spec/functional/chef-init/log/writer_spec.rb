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
require 'chef-init/log'

describe 'ChefInit::Log::Writer' do
  let(:stdin_io) { StringIO.new }
  let(:stdout_io) { StringIO.new }
  let(:log_pipe) { IO.pipe }

  before do
    allow(File).to receive(:exist?).with('/opt/chef/logs').and_return(true)
    allow(IO).to receive(:open).with('/opt/chef/logs', 'w+').and_return(log_pipe[1])
  end

  let(:service1) do
    ChefInit::Log::Writer.new(['service1']).tap do |logger|
      allow(logger).to receive(:input).and_return(stdin_io)
      allow(logger).to receive(:service_name).and_return('service1')
    end
  end

  let(:service2) do
    ChefInit::Log::Writer.new(['service2']).tap do |logger|
      allow(logger).to receive(:input).and_return(stdin_io)
      allow(logger).to receive(:service_name).and_return('service2')
    end
  end

  let(:service3) do
    ChefInit::Log::Writer.new(['service3']).tap do |logger|
      allow(logger).to receive(:input).and_return(stdin_io)
      allow(logger).to receive(:service_name).and_return('service3')
    end
  end

  # make sure that our pipe is grabbing everything
  describe 'with a single service running' do
    it 'forwards logs to ChefInit::Log::Reader pipe' do
      service1.send_to_pid1('test log line')
      expect(log_pipe[0].gets.chomp).to eql('[service1] test log line')
    end
  end

  describe 'with two services running' do
    it 'forwards logs to ChefInit::Log::Reader pipe' do
      service1.send_to_pid1('test log line')
      service2.send_to_pid1('test log line')
      service1.send_to_pid1('test log line 2')
      expect(log_pipe[0].gets.chomp).to eql('[service1] test log line')
      expect(log_pipe[0].gets.chomp).to eql('[service2] test log line')
      expect(log_pipe[0].gets.chomp).to eql('[service1] test log line 2')
    end
  end

end
