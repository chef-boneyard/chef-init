require 'spec_helper'

class FakeClass
  include ChefInit::Helpers
end

describe ChefInit::Helpers do
  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }



  describe ".system_command" do
    
  end

  describe ".err" do
    before do
      @klass = FakeClass.new
      @klass.stub(:stderr).and_return(stderr_io)  
    end

    it "should print message to stderr" do
      @klass.err "test"
      expect(stderr_io.string).to eql("test\n")
    end
  end
end
