require 'spec_helper'
require 'chef/resource/runit_supervisor'
require 'chef/provider/supervisor/runit'

describe Chef::Provider::Supervisor::Runit do 
  before(:each) do
    @node = Chef::Node.new
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {},  @events)

    @new_resource = Chef::Resource::RunitSupervisor.new("nginx")
    @current_resource = Chef::Resource::RunitSupervisor.new("nginx")

    @provider = Chef::Provider::Supervisor::Runit.new(@new_resource, @run_context)

    Chef::Resource::RunitSupervisor.stub(:new).and_return(@current_resource)
    File.stub(:exists?).with("/opt/chef/embedded/bin/sv").and_return(true)
    File.stub(:executable?).with("/opt/chef/embedded/bin/sv").and_return(true)
  end

  describe "define_resource_requirements" do
     
  end

  describe "load_current_resource" do
    it "should set the service_name" do
      @provider.load_current_resource
      expect(@current_resource.service_name).to eql("nginx")      
    end

    context "when supervisor is already enabled" do
      it "should set enabled to be true" do
        File.stub(:exist?).with("/opt/chef/service/nginx/run").and_return(true)
        @provider.load_current_resource
        expect(@current_resource.enabled).to eql(true)
      end
    end

    context "when supervisor is not enabled" do
      it "should set enabled to be false" do
        File.stub(:exist?).with("/opt/chef/service/nginx/run").and_return(false)
        @provider.load_current_resource
        expect(@current_resource.enabled).to eql(false)
      end
    end
  end

  describe "enable_supervisor" do
    before do
      File.stub(:exist?).with("/opt/chef/service/nginx/run").and_return(true)
    end

    it 'creates the necessary files and folder' do
      @provider.load_current_resource
      @provider.action_enable
      expect{ @provider.instance_eval{ @service_dir }}.to_not eql(nil)
      expect{ @provider.instance_eval{ @down_file }}.to_not eql(nil)
      expect{ @provider.instance_eval{ @run_script }}.to_not eql(nil)
      expect{ @provider.instance_eval{ @log_dir }}.to_not eql(nil)
      expect{ @provider.instance_eval{ @log_main_dir }}.to_not eql(nil)
      expect{ @provider.instance_eval{ @log_run_script }}.to_not eql(nil)
    end
  end

end
