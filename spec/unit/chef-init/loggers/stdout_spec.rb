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
require 'chef-init/loggers/stdout'

describe 'ChefInit::Loggers::Stdout' do
  let(:stdout_io) { StringIO.new }

  subject(:stdout_logger) do
    ChefInit::Loggers::Stdout.new.tap do |c|
      allow(c).to receive(:stdout).and_return(stdout_io)
    end
  end

  describe '#write' do
    it 'writes output to stdout' do
      stdout_logger.write('test log line')
      expect(stdout_io.string).to eql("test log line\n")
    end
  end
end
