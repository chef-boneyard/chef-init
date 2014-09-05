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

class FakeClass
  include ChefInit::Helpers
end

describe ChefInit::Helpers do
  let(:stdout_io) { StringIO.new }
  let(:stderr_io) { StringIO.new }

  describe ".system_command" do
    before do
     @klass = FakeClass.new
     allow(Mixlib::ShellOut).to receive(:new).with("true").and_return(cmd)
    end

    let(:cmd) { double("ShellOut Object", run_command: nil)}

    it "should create Mixlib::ShellOut object" do
      expect(Mixlib::ShellOut).to receive(:new).and_return(cmd)
      @klass.system_command("true")
    end

    it "should run the command" do
      expect(cmd).to receive(:run_command)
      @klass.system_command("true")
    end

    it "should return the ShellOut object" do
      obj = @klass.system_command("true")
      expect(obj).to eql(cmd)
    end
  end

  describe ".err" do
    before do
      @klass = FakeClass.new
      allow(@klass).to receive(:stderr).and_return(stderr_io)
    end

    it "should print message to stderr" do
      @klass.err "test"
      expect(stderr_io.string).to eql("test\n")
    end
  end

  describe ".msg" do
    before do
      @klass = FakeClass.new
      allow(@klass).to receive(:stdout).and_return(stdout_io)
    end

    it "should print message to stdout" do
      @klass.msg "test"
      expect(stdout_io.string).to eql("test\n")
    end
  end

  describe ".omnibus_root" do
    before do
      @klass = FakeClass.new
    end

    subject { @klass.omnibus_root }
    it { should eql "/opt/chef" }
  end

  describe ".omnibus_bin_dir" do
    before do
      @klass = FakeClass.new
    end

    subject { @klass.omnibus_bin_dir }
    it { should eql "/opt/chef/bin" }
  end

  describe ".omnibus_embedded_bin_dir" do
    before do
      @klass = FakeClass.new
    end

    subject { @klass.omnibus_embedded_bin_dir }
    it { should eql "/opt/chef/embedded/bin" }
  end
end
