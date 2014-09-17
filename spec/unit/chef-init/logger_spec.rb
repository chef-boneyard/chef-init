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
require 'chef-init/logger'

describe 'ChefInit::Logger' do

  subject(:logger) do
    ChefInit::Logger.new(argv).tap do |c|
      c.parse_options(argv)
    end
  end

  describe '#logger' do
    let(:argv) { %w( --service-name test --log-destination stdout )}

    it 'returns the class constant for the logger' do
      expect(logger.logger).to eql(ChefInit::Loggers::Stdout)
    end

    context 'when invalid log destination has been specified' do
      let(:argv) { %w( --service-name test --log-destination invalid )}

      it 'raises InvalidLogDestination error' do
        expect{ logger.logger }.to raise_error(ChefInit::Exceptions::InvalidLogDestination)
      end
    end
  end
end
