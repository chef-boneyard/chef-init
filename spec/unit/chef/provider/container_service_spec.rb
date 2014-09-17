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

require 'chef/provider/container_service'

describe Chef::Provider::ContainerService do

  before(:each) do
    @provider = Chef::Provider::ContainerService.new("foo")
  end

  it 'should return a Chef::Provider::ContainerService' do
    expect(@provider).to be_a_kind_of(Chef::Provider::ContainerService)
  end

  it 'should extend Chef::Provider::Service' do
    expect(@provider).to be_a_kind_of(Chef::Provider::Service)
  end
end
