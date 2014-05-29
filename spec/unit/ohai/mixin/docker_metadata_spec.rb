require 'spec_helper'
require 'ohai'
require 'ohai/mixin/docker_container_metadata'

describe Ohai::Mixin::DockerContainerMetadata do

  context "when socket does not exist" do
    describe "can_metadata_connect?" do
      let(:mixin) {
        Ohai::Mixin::DockerContainerMetadata::DOCKER_METADATA_ADDR = "fake"
        Object.new.extend(Ohai::Mixin::DockerContainerMetadata)
      }

      it "should return false" do
        mixin.can_metadata_connect?.should eql(false)
      end
    end
  end

  context "when socket exists" do
    
    context "and container exists" do
      let(:mixin) {
        metadata_object = Object.new.extend(Ohai::Mixin::DockerContainerMetadata)
        @shell_out = double("shellout", :stdout => "myhostname\n")
        @response = double("response", :body => "{\"metadata\": true}", :code => '200')
        metadata_object.stub(:request).and_return(@response)
        metadata_object.stub(:shell_out).and_return(@shell_out)
        metadata_object
      }


      describe "#container_id" do
        it "should return the hostname" do
          mixin.container_id.should eql("myhostname")   
        end
      end
      
      describe "#fetch_metadata" do
        let(:parser) { double("JSON Parser", :parse => nil) }
        let(:data) { double("StringIO data") }

        it "should make a request to API" do
          mixin.should_receive(:request).with("/containers/myhostname/json")
          mixin.fetch_metadata
        end

        it "should parse the response body" do
          Yajl::Parser.stub(:new).and_return(parser)
          StringIO.should_receive(:new).with("{\"metadata\": true}").and_return(data)
          Yajl::Parser.should_receive(:new).and_return(parser)
          parser.should_receive(:parse).with(data)
          mixin.fetch_metadata
        end
      end
    end

    context "and matching container cannot be found" do
      describe "#can_find_container?" do
        let(:response) { double("Net::HTTP::Get Response", :body => "No such container: mylittlecontainer", :code => 404) }
        let(:mixin) {
          metadata_object = Object.new.extend(Ohai::Mixin::DockerContainerMetadata)
          metadata_object.stub(:request).and_return(response)
          metadata_object.stub(:container_id).and_return("mylittlecontainer")
          metadata_object
        }
        it "should return false" do
          mixin.can_find_container?.should eql(false)
        end
      end
    end
  end

end
