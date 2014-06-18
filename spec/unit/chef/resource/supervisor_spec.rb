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
require 'chef/resource/supervisor'

describe Chef::Resource::Supervisor do

  before(:each) do
    @resource = Chef::Resource::Supervisor.new("foo")
  end

  it 'should return a Chef::Resource::Supervisor' do
    expect(@resource).to be_a_kind_of(Chef::Resource::Supervisor)
  end

  it 'should be a sub-class of Chef::Resource::Service' do
    expect(@resource).to be_a_kind_of(Chef::Resource::Service)
  end

  it 'should have a resource name of :supervisor' do
    expect(@resource.resource_name).to eql(:supervisor)
  end

  it 'should have a provider of Chef::Provider::Supervisor::Runit' do
    expect(@resource.provider).to eql(Chef::Provider::Supervisor::Runit)
  end

end
