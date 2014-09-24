#! /usr/bin/env bats
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

load helpers

@test "Failing chef-client run causes chef-init --bootstrap to exit with non-zero" {
  run chef_init_bootstrap "zero" "failing"
  assert_failure
  assert_output_contains "No such cookbook: foobar"
  assert_cleanup_success
}

@test "Successful chef-client run causes chef-init --bootstrap to exit with zero" {
  run chef_init_bootstrap "zero" "passing"
  assert_success
  assert_output_contains "Chef Run complete"
  assert_cleanup_success
}

@test "chef-init --bootstrap supports proper convergence" {
  run chef_init_bootstrap "zero" "passing" # run 1
  assert_success
  assert_output_contains "Chef Run complete"
  run chef_init_bootstrap "zero" "passing" # run 2
  assert_success
  assert_output_contains "Chef Run complete"
  assert_cleanup_success
}
