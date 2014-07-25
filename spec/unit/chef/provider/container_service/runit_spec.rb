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
require 'chef/provider/container_service/runit'

describe Chef::Provider::ContainerService::Runit do
  def runit_signal(action)
    "/opt/chef/embedded/bin/sv #{action} /opt/chef/service/foo"
  end

  before(:each) do
    @node = Chef::Node.new
    @node.normal['container_service']['foo']['command'] = "/usr/bin/foo"

    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {},  @events)

    @new_resource = Chef::Resource::Service.new("foo", @run_context)
    @current_resource = Chef::Resource::Service.new("foo", @run_context)

    @provider = Chef::Provider::ContainerService::Runit.new(@new_resource, @run_context)

    Chef::Resource::Service.stub(:new).and_return(@current_resource)
  end

  describe "#initialize" do

    it "should grab the service command from the node object" do
      expect(@provider.command).to eql("/usr/bin/foo")
    end

  end

  describe "#load_current_resource" do
    let(:command_success) { double("ShellOut Object", exitstatus: 0, stdout: 'run: ok') }
    before do
      @provider.stub(:running?)
      @provider.stub(:enabled?)
      @provider.stub(:setup)
    end

    it "should setup the runit prerequisites" do
      expect(@provider).to receive(:setup)
      @provider.load_current_resource
    end

    it "should set the service_name" do
      @provider.stub(:running?).and_return(true)
      @provider.stub(:enabled?).and_return(true)
      @provider.load_current_resource
      expect(@current_resource.service_name).to eql("foo")
    end

    context "when supervisor is already running" do
      it "should set running to be true" do
        @provider.stub(:running?).and_return(true)
        @provider.load_current_resource
        expect(@current_resource.running).to eql(true)
      end
    end

    context "when supervisor is not running" do
      it "should set running to be false" do
        @provider.stub(:running?).and_return(false)
        @provider.load_current_resource
        expect(@current_resource.running).to eql(false)
      end
    end

    context "when supervisor is already enabled" do
      it "should set enabled to be true" do
        @provider.stub(:enabled?).and_return(true)
        @provider.load_current_resource
        expect(@current_resource.enabled).to eql(true)
      end
    end

    context "when supervisor is not enabled" do
      it "should set enabled to be false" do
        @provider.stub(:enabled?).and_return(false)
        @provider.load_current_resource
        expect(@current_resource.enabled).to eql(false)
      end
    end

    it "should inspect current state of system and return a new Chef::Resource::Service object" do
      expect(@provider.load_current_resource).to be_a_instance_of(Chef::Resource::Service)
    end
  end

  describe "#setup" do
    let(:staging_dir) { double("staging_dir", run_action: nil) }
    let(:down_file) { double("down_file", run_action: nil) }
    let(:run_script) { double("run_script", run_action: nil) }
    let(:log_dir) { double("log_dir", run_action: nil) }
    let(:log_main_dir) { double("log_main_dir", run_action: nil) }
    let(:log_run_script) { double("log_run_script", run_action: nil) }
    let(:service_dir_link) { double("service_dir_link", run_action: nil) }

    before do
      @provider.stub(:staging_dir).and_return(staging_dir)
      @provider.stub(:down_file).and_return(down_file)
      @provider.stub(:run_script).and_return(run_script)
      @provider.stub(:log_dir).and_return(log_dir)
      @provider.stub(:log_main_dir).and_return(log_main_dir)
      @provider.stub(:log_run_script).and_return(log_run_script)
      @provider.stub(:service_dir_link).and_return(service_dir_link)
      @provider.stub(:running?).and_return(true)
      @provider.stub(:enabled?).and_return(false)
    end

    it 'creates the service directory and run scripts' do
      expect(staging_dir).to receive(:run_action).with(:create)
      expect(down_file).to receive(:run_action).with(:create)
      expect(run_script).to receive(:run_action).with(:create)
      expect(log_dir).to receive(:run_action).with(:create)
      expect(log_main_dir).to receive(:run_action).with(:create)
      expect(log_run_script).to receive(:run_action).with(:create)
      expect(service_dir_link).to receive(:run_action).with(:create)
      @provider.load_current_resource
    end
  end

  ##
  # Service Command Overrides
  #
  describe "#enable_service" do
    let(:down_file) { double("down_file resource", run_action: nil) }

    before do
      @provider.stub(:down_file).and_return(down_file)
    end

    it 'should delete down_file' do
      expect(down_file).to receive(:run_action).with(:delete)
      @provider.enable_service
    end
  end

  describe "#disable_service" do
    let(:down_file) { double("down_file resource", run_action: nil) }

    before do
      @provider.stub(:down_file).and_return(down_file)
      @provider.stub(:shell_out)
    end

    it 'should create down_file' do
      expect(down_file).to receive(:run_action).with(:create)
      @provider.disable_service
    end

    it 'should send down command to sv' do
      expect(@provider).to receive(:shell_out).with(runit_signal("down"))
      @provider.disable_service
    end
  end

  describe "#start_service" do
    before do
      @provider.stub(:shell_out!)
      @provider.stub(:wait_for_service_enable)
    end

    it 'should send start command via sv' do
      expect(@provider).to receive(:wait_for_service_enable)
      expect(@provider).to receive(:shell_out!).with(runit_signal("start"))
      @provider.start_service
    end
  end

  describe "#stop_service" do
    before do
      @provider.stub(:shell_out!)
    end

    it 'should send stop command via sv' do
      expect(@provider).to receive(:shell_out!).with(runit_signal("stop"))
      @provider.stop_service
    end
  end

  describe "#restart_service" do
    before do
      @provider.stub(:shell_out!)
    end

    it 'should send restart command via sv' do
      expect(@provider).to receive(:shell_out!).with(runit_signal("restart"))
      @provider.restart_service
    end
  end

  describe "#reload_service" do
    before do
      @provider.stub(:shell_out!)
    end

    it 'should send reload command via sv' do
      expect(@provider).to receive(:shell_out!).with(runit_signal("force-reload"))
      @provider.reload_service
    end
  end

  ##
  # Load Current Resource Helpers
  #
  describe "#running?" do
    let(:command) { double("shell_out", stdout: 'run: ok', exitstatus: 0)}

    before do
      @provider.stub(:shell_out).and_return(command)
    end

    it "should get current status of process" do
      expect(@provider).to receive(:shell_out).with(runit_signal("status"))
      expect(command).to receive(:stdout)
      expect(command).to receive(:exitstatus)
      @provider.running?
    end

    context "service is not running" do
      let(:command) { double("shell_out", stdout: 'error: not ok', exitstatus: 1) }

      before do
        @provider.stub(:shell_out).with(runit_signal("status")).and_return(command)
      end

      it "should return false" do
        status = @provider.running?
        expect(status).to eql(false)
      end
    end

    context "service is running" do
      let(:command) { double("shell_out", stdout: 'run: ok', exitstatus: 0) }

      before do
        @provider.stub(:shell_out).with(runit_signal("status")).and_return(command)
      end

      it "should return true" do
        status = @provider.running?
        expect(status).to eql(true)
      end
    end
  end

  describe "#enabled?" do
    context "service is enabled" do
      before do
        File.stub(:exists?).with("/opt/chef/service/foo/down").and_return(false)
      end

      it "should return true" do
        enabled = @provider.enabled?
        expect(enabled).to eql(true)
      end
    end

    context "service is not enabled" do
      before do
        File.stub(:exists?).with("/opt/chef/service/foo/down").and_return(true)
      end

      it "should return true" do
        enabled = @provider.enabled?
        expect(enabled).to eql(false)
      end
    end
  end

  ##
  # Misc Helpers
  describe "#wait_for_service" do

  end

  describe "#service_dir_name" do
    it 'returns the service directory name' do
      expect(@provider.service_dir_name).to eql("/opt/chef/service/foo")
    end
  end

  describe "#staging_dir_name" do
    it "returns the staging directory name" do
      expect(@provider.staging_dir_name).to eql("/opt/chef/sv/foo")
    end
  end

  describe "#sv_bin" do
    it "returns the sv binary location" do
      expect(@provider.sv_bin).to eql("/opt/chef/embedded/bin/sv")
    end
  end

  ##
  # Chef Resources
  #
  describe "#run_script_content" do
    let(:expected_content) { "#!/bin/sh\nexec 2>&1\nexec /usr/bin/foo 2>&1" }
    it "returns a string with the run script content" do
      expect(@provider.instance_eval { run_script_content }).to eql(expected_content)
    end
  end

  describe "#log_run_script_content" do
    let(:expected_content) { "#!/bin/sh\nexec svlogd -tt /var/log/foo" }
    it "returns a string with the run script content" do
      expect(@provider.instance_eval { log_run_script_content }).to eql(expected_content)
    end
  end


  describe "#staging_dir" do
    let(:staging_dir) { double("staging_dir", recursive: nil, mode: nil) }

    before do
      Chef::Resource::Directory.stub(:new).with("/opt/chef/sv/foo", anything).and_return(staging_dir)
    end

    it 'should create the /opt/chef/sv/{service} directory' do
      expect(Chef::Resource::Directory).to receive(:new).with("/opt/chef/sv/foo", anything)
      expect(staging_dir).to receive(:recursive).with(true)
      expect(staging_dir).to receive(:mode).with(00755)
      expect(@provider.instance_eval { staging_dir }).to eql(staging_dir)
    end
  end

  describe "#down_file" do
    let(:down_file) { double("down_file", mode: nil, backup: nil) }

    before do
      Chef::Resource::File.stub(:new).with("/opt/chef/sv/foo/down", anything).and_return(down_file)
    end

    it 'should create the /opt/chef/sv/{service}/down file' do
      expect(Chef::Resource::File).to receive(:new).with("/opt/chef/sv/foo/down", anything).and_return(down_file)
      expect(down_file).to receive(:backup).with(false)
      expect(@provider.instance_eval { down_file }).to eql(down_file)
    end
  end

  describe "#run_script" do
    let(:run_script) { double("run_script", content: nil, mode: nil) }

    before do
      Chef::Resource::File.stub(:new).with("/opt/chef/sv/foo/run", anything).and_return(run_script)
      @provider.stub(:run_script_content).and_return("go!")
    end

    it 'should create the /opt/chef/sv/{service}/run file' do
      expect(Chef::Resource::File).to receive(:new).with("/opt/chef/sv/foo/run", anything).and_return(run_script)
      expect(run_script).to receive(:content).with("go!")
      expect(run_script).to receive(:mode).with(00755)
      expect(@provider.instance_eval { run_script }).to eql(run_script)
    end
  end

  describe "#log_dir" do
    let(:log_dir) { double("log_dir", recursive: nil, mode: nil) }

    before do
      Chef::Resource::File.stub(:new).with("/var/log/foo", anything)
    end

    it 'should create the /var/log/{service} directory' do
      expect(Chef::Resource::Directory).to receive(:new).with("/var/log/foo", anything).and_return(log_dir)
      expect(log_dir).to receive(:recursive).with(true)
      expect(log_dir).to receive(:mode).with(00755)
      expect(@provider.instance_eval { log_dir }).to eql(log_dir)
    end
  end

  describe "#log_main_dir" do
    let(:log_main_dir) { double("log_main_dir", recursive: nil, mode: nil) }

    before do
      Chef::Resource::File.stub(:new).with("/opt/chef/sv/foo/log", anything)
    end

    it 'should create the /var/log/{service} directory' do
      expect(Chef::Resource::Directory).to receive(:new).with("/opt/chef/sv/foo/log", anything).and_return(log_main_dir)
      expect(log_main_dir).to receive(:recursive).with(true)
      expect(log_main_dir).to receive(:mode).with(00755)
      expect(@provider.instance_eval { log_main_dir }).to eql(log_main_dir)
    end
  end

  describe "#log_run_script" do
    let(:log_run_script) { double("log_run_script", content: nil, mode: nil) }

    before do
      Chef::Resource::File.stub(:new).with("/opt/chef/sv/foo/log/run", anything).and_return(log_run_script)
      @provider.stub(:log_run_script_content).and_return("go!")
    end

    it 'should create the /opt/chef/sv/{service}/log/run file' do
      expect(Chef::Resource::File).to receive(:new).with("/opt/chef/sv/foo/log/run", anything).and_return(log_run_script)
      expect(log_run_script).to receive(:content).with("go!")
      expect(log_run_script).to receive(:mode).with(00755)
      expect(@provider.instance_eval { log_run_script }).to eql(log_run_script)
    end
  end

  describe "#service_dir_link" do
    let(:service_dir_link) { double("service_dir_link", to: nil) }

    before do
      Chef::Resource::Link.stub(:new).with("/opt/chef/service/foo", anything).and_return(service_dir_link)
    end

    it 'creates a symlink between /opt/chef/sv/{service} and /opt/chef/service/{service}' do
      expect(Chef::Resource::Link).to receive(:new).with("/opt/chef/service/foo", anything).and_return(service_dir_link)
      expect(service_dir_link).to receive(:to).with("/opt/chef/sv/foo")
      expect(@provider.instance_eval { service_dir_link }).to eql(service_dir_link)
    end
  end
end
