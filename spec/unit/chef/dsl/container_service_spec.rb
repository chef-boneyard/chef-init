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
require 'chef/dsl/container_service'

describe Chef::DSL::Recipe do
  before(:each) do
    @cookbook_repo = File.expand_path(File.join(File.dirname(__FILE__), "..", "data", "cookbooks"))
    cl = Chef::CookbookLoader.new(@cookbook_repo)
    cl.load_cookbooks
    @cookbook_collection = Chef::CookbookCollection.new(cl)
    @node = Chef::Node.new
    @node.normal[:tags] = Array.new
    @node.normal[:container_service] = Mash.new
    @node.normal[:container_service][:foo] = Mash.new
    @node.normal[:container_service][:foo][:command] = "/usr/bin/foo"
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, @cookbook_collection, @events)
    @recipe = Chef::Recipe.new("chef", "container", @run_context)
    @recipe.stub(:pp)
  end

  describe "#service" do

    let(:resource) { double("resource", command: nil) }

    before do
      @recipe.stub(:declare_resource).and_return(resource)
    end

    it "should detect whether a command for the service exists in the node object" do
      expect(@recipe).to receive(:valid_supervisor_command_specified?).with("foo")
      @recipe.service "foo"
    end

    context "when supervisor command exists" do
      it "should declare the supervisor resource" do
        expect(@recipe).to receive(:declare_resource).with(:supervisor, "foo", anything)
        @recipe.service "foo"
      end

      it "should add the supervisor command to the resource object" do
        expect(resource).to receive(:command).with("/usr/bin/foo")
        @recipe.service "foo"
      end
    end

    context "when supervisor command does not exist" do
      it "should declare the default service resource" do
        expect(@recipe).to receive(:declare_resource).with(:service, "bar", anything)
        @recipe.service "bar"
      end
    end
  end

  describe ".valid_supervisor_command_specified?" do
    context "attribute is found" do
      it "returns the command" do
        expect(@recipe.valid_supervisor_command_specified?("foo")).to eql("/usr/bin/foo")
      end
    end

    context "attribute is not found" do
      it "returns nil" do
        expect(@recipe.valid_supervisor_command_specified?("bar")).to eql(nil)
      end
    end
  end
end
