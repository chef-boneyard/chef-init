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

setup() {
  refresh_tmpdata
  start_chef_server
}

teardown() {
  stop_chef_server
  teardown_common
}

@test "Failing chef-client run causes chef-init --bootstrap running in server-mode to exit with non-zero" {
  run chef_init_bootstrap --runlist "recipe[foobar]"
  assert_failure
  assert_output_contains "No such cookbook: foobar"
  echo "$output" > /tmp/log
  assert_cleanup_success
}

@test "Successful chef-client run causes chef-init --bootstrap running in server-mode to exit with zero" {
  skip
  run chef_init_bootstrap "client" "passing"
  assert_success
  assert_output_contains "Chef Run complete"
  assert_cleanup_success
}

@test "chef-init --bootstrap running in server-mode does not leave artifacts on chef server" {
  skip
  run knife node list --config "$FIXTURE_ROOT/client.rb"
  assert_success
  assert_output_contains ""

  run knife client list --config "$FIXTURE_ROOT/client.rb"
  assert_success
  assert_output_contains ""
}
