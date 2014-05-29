
require 'spec_helper'

describe Ohai::System, "plugin docker_container" do
  before(:each) do
    @plugin = get_plugin("docker_container")
  end

  shared_examples_for "!docker" do
    
  end

  shared_examples_for "docker" do

    before(:each) do
      @plugin.stub(:container_id).and_return("mylittlecontainer")
      
      # Stub can_metadata_connect stuff
      IO.stub(:select).and_return([[],[1],[]])
      t = double("connection")
      t.stub(:connect_nonblock).and_raise(Errno::EINPROGRESS)
      Socket.stub(:new).and_return(t)
      Socket.stub(:pack_sockaddr_un).and_return(nil)
    end

    let(:json_response) {
      <<-EOH
{
  "Id": "mylittlecontainerismyshortname",
  "Config": {
    "Hostname": "mylittlecontainer",
    "Memory": 0,
    "AttachStdin": false,
    "Cmd": [
      "chef-init"
    ]
  },
  "HostConfig": {
    "PortBindings": {
      "80/tcp": [
        {
          "HostIp": "0.0.0.0",
          "HostPort": "49153"
        }
      ]
    }
  }
}
      EOH
    }

    let(:response) { double("Net::HTTPResponse", :code => "200", :body => json_response) }

    it "should recursively fetch and properly parse json metadata" do
      @plugin.should_receive(:request).twice.with("/containers/mylittlecontainer/json").and_return(response)

      @plugin.run

      @plugin[:docker_container].should_not be_nil
      @plugin[:docker_container]['Id'].should eql("mylittlecontainerismyshortname")
      @plugin[:docker_container]['Config'].should_not be_nil
      @plugin[:docker_container]['Config']['Memory'].should eql(0)
      @plugin[:docker_container]['Config']['AttachStdin'].should eql(false)
      @plugin[:docker_container]['Config']['Cmd'].should eql(["chef-init"])
      @plugin[:docker_container]['HostConfig']['PortBindings']['80/tcp'][0].should eql({"HostIp" => "0.0.0.0", "HostPort" => "49153"})
    end
  end

  describe "when socket file does not exist" do
    it_should_behave_like "!docker"    
  end

  describe "when socket file exists" do
    it_should_behave_like "docker"
  end
end
