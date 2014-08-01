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

require 'chef-init/verify'
require 'chef-init/helpers'
require 'spec_helper'

describe ChefInit::Test do
  before(:each) { ChefInit::Test.class_variable_set :@@failed_tests, [] }

  subject(:test_case) { ChefInit::Test.new("foo") }
  subject(:test_case2) { ChefInit::Test.new("bar") }

  describe "#pass" do
    it "should print out a line to ChefInit::Log.info" do
      expect(ChefInit::Log).to receive(:info).with("foo: pass")
      test_case.pass
    end
  end

  describe ".did_pass?" do
    context "when all test cases pass" do
      it "should return true" do
        test_case.pass
        test_case2.pass
        expect(ChefInit::Test.did_pass?).to eql(true)
      end
    end

    context "when at least one test case fails" do
      it "should return false" do
        test_case.pass
        test_case2.fail "error"
        expect(ChefInit::Test.did_pass?).to eql(false)
      end
    end

    context "when all test cases fail" do
      it "should return false" do
        test_case.fail "error"
        test_case2.fail "error"
        expect(ChefInit::Test.did_pass?).to eql(false)
      end
    end
  end

  describe "#fail" do
    it "should print out a line to ChefInit::Log.error" do
      expect(ChefInit::Log).to receive(:error).with("foo: fail")
      test_case.fail "error msg"
    end

    it "should add that error message to the global attribute @@failed_tests" do
      test_case.fail "error msg"
      expect(ChefInit::Test.failed_tests).to include("error msg")
    end
  end

  describe ".failed_tests" do
    it "should return an array of all the failed messages" do
      test_case.fail "error msg"
      test_case2.fail "error msg too"
      expect(ChefInit::Test.failed_tests).to eql(["error msg", "error msg too"])
    end
  end
end
