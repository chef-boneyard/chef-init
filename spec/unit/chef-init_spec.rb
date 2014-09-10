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
require 'chef-init'
require 'chef/platform'
require 'chef/node'

describe ChefInit do

  describe "`service` resource" do

    context "when the container_service node attribute is present" do

      it "sets the provider to ContainerService::Runit" do
        node = Chef::Node.new
        node.name("foo")
        node.normal_attrs[:container_service][:foo][:command] = "/usr/bin/foo"
        node.automatic_attrs[:platform] = "ubuntu"
        node.automatic_attrs[:platform_version] = "12.04"

        events = Chef::EventDispatch::Dispatcher.new
        run_context = Chef::RunContext.new(node, {},  events)

        service = Chef::Resource::Service.new("foo", run_context)

        expect(service.provider).to eql(Chef::Provider::ContainerService::Runit)
      end

    end
  end

  describe ".node_name" do

    context "when ENV variable is specified" do
      before { ENV['CHEF_NODE_NAME'] = 'mynodename' }
      after { ENV['CHEF_NODE_NAME'] = nil }

      it "should return the value of the environment variable" do
        expect(ChefInit.node_name).to eql("mynodename")
      end
    end

    context "when .node_name file exists" do
      before do
        allow(File).to receive(:exist?).with("/etc/chef/.node_name").and_return(true)
        allow(File).to receive(:read).with("/etc/chef/.node_name").and_return("docker-demo-build")
      end

      it "should return the contents of the file" do
        expect(ChefInit.node_name).to eql("docker-demo-build")
      end
    end

    context "by default" do
      it "should return nil" do
        expect(ChefInit.node_name).to eql(nil)
      end
    end

  end
end
