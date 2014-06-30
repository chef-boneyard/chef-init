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
require 'chef/resource/container_service'

describe Chef::Resource::ContainerService do

  before(:each) do
    @node = Chef::Node.new
    @node.normal['container_service']['foo']['command'] = "/usr/bin/foo"

    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {},  @events)

    @resource = Chef::Resource::ContainerService.new("foo", @run_context)
  end

  it 'should return a Chef::Resource::Supervisor' do
    expect(@resource).to be_a_kind_of(Chef::Resource::ContainerService)
  end

  it 'should be a sub-class of Chef::Resource::Service' do
    expect(@resource).to be_a_kind_of(Chef::Resource::Service)
  end

  it 'should have a resource name of :service' do
    expect(@resource.resource_name).to eql(:service)
  end

  context "when a node attribute with a service command is specified" do

    it 'should have a provider of Chef::Provider::ContainerService::Runit' do
      expect(@resource.provider).to eql(Chef::Provider::ContainerService::Runit)
    end

  end

end
