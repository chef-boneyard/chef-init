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

describe 'ChefInit::Log::Reader' do
  let(:pipe) { IO.pipe }
  let(:stdout_io) { StringIO.new }

  subject(:reader) do
    ChefInit::Log::Reader.new('/opt/chef/logs').tap do |c|
      allow(c).to receive(:open_pipe).and_return(pipe[0])
      allow(c).to receive(:output).and_return(stdout_io)
    end
  end

  it 'reads from a log pipe and prints to STDOUT' do
    reader.run
    pipe[1].puts('[service1] test line 1')
    pipe[1].flush
    pipe[1].puts('[service1] test line 2')
    pipe[1].flush
    pipe[1].puts('[service2] test line 1')
    pipe[1].flush
    sleep 0.5
    expect(stdout_io.string).to eql("[service1] test line 1\n[service1] test line 2\n[service2] test line 1\n")
    reader.kill
  end
end
