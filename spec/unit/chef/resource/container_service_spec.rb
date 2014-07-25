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

describe Chef::Resource::Service do

  describe "when a node attribute with a service command is specified" do
    before(:each) do
      @node = Chef::Node.new
      @node.normal['container_service']['foo']['command'] = "/usr/bin/foo"

      @events = Chef::EventDispatch::Dispatcher.new
      @run_context = Chef::RunContext.new(@node, {},  @events)

      @resource = Chef::Resource::Service.new("foo", @run_context)
    end

    it 'has a provider of Chef::Provider::ContainerService::Runit' do
      expect(@resource.provider).to eql(Chef::Provider::ContainerService::Runit)
    end
  end

  describe "#container_service_command_specified?" do
    context "when the command attribute is specified" do
      it "returns true" do
        node = Chef::Node.new
        node.normal['container_service']['foo']['command'] = "/usr/bin/foo"
        events = Chef::EventDispatch::Dispatcher.new
        run_context = Chef::RunContext.new(node, {},  events)

        resource = Chef::Resource::Service.new("foo", run_context)
        expect(resource.container_service_command_specified?).to eql(true)
      end
    end

    context "when another command is specified" do
      it "returns false" do
        node = Chef::Node.new
        node.normal['container_service']['bar']['command'] = "/usr/bin/bar"
        events = Chef::EventDispatch::Dispatcher.new
        run_context = Chef::RunContext.new(node, {},  events)

        resource = Chef::Resource::Service.new("foo", run_context)
        expect(resource.container_service_command_specified?).to eql(false)
      end
    end

    context "when no command attribute is specified" do
      it "returns false" do
        node = Chef::Node.new
        events = Chef::EventDispatch::Dispatcher.new
        run_context = Chef::RunContext.new(node, {},  events)

        resource = Chef::Resource::Service.new("foo", run_context)
        expect(resource.container_service_command_specified?).to eql(false)
      end
    end
  end

end
