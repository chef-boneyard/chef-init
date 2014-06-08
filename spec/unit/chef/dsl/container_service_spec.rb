require 'spec_helper'
require 'chef/dsl/container_service'

describe Chef::Recipe do
  before(:each) do
    @cookbook_repo = File.expand_path(File.join(File.dirname(__FILE__), "..", "data", "cookbooks"))
    cl = Chef::CookbookLoader.new(@cookbook_repo)
    cl.load_cookbooks
    @cookbook_collection = Chef::CookbookCollection.new(cl)
    @node = Chef::Node.new
    @node.normal[:tags] = Array.new
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, @cookbook_collection, @events)
    @recipe = Chef::Recipe.new("chef", "container", @run_context)
    @recipe.stub(:pp)
  end

  describe "#container_service" do
    let(:supervisor_class) { double("Chef::Resource::Supervisor") }
    let(:supervisor_resource) { double("apache2", command: nil, run_action: nil, provider: Chef::Provider::Supervisor::Runit) }

    before do
      allow(Chef::Resource::Supervisor).to receive(:new).and_return(supervisor_resource)
    end

    let(:run_chef_init) do
      @recipe.service "apache2"
      @recipe.container_service "apache2" do
        command "apache2 start"
      end
    end

    context 'can not find an existing `service` resource with the same name' do
      it 'should raise an error' do
        expect{
          @recipe.service "apache" 
          @recipe.container_service "apache2"
        }.to raise_error(Chef::Exceptions::ResourceNotFound)
      end
    end

    context 'can find matching `service` resource' do
      let(:supervisor) { double("Supervisor Resource", run_action: nil, provider: Chef::Provider::Supervisor::Runit) }

      it 'should set the provider of the `service` resource to the new provider' do
        run_chef_init 
        service_resource = @run_context.resource_collection.find("service[apache2]")
        provider = service_resource.instance_exec { @provider }
        expect(provider).to eql(Chef::Provider::Supervisor::Runit)
      end

      it 'should create a new process supervisor' do
        Chef::Resource::Supervisor.stub(:new).and_return(supervisor)
        expect(Chef::Resource::Supervisor).to receive(:new).with("apache2", @run_context)
        expect(supervisor).to receive(:instance_exec)
        expect(supervisor).to receive(:run_action).with(:setup)
        run_chef_init
      end
    end

    it 'should configure and enable the supervisor' do
      Chef::Resource::Supervisor.stub(:new).and_return(supervisor_resource)
      expect(supervisor_resource).to receive(:instance_exec)
      expect(supervisor_resource).to receive(:run_action)
      run_chef_init
    end
  end
end
