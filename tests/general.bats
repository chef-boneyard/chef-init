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

@test "Binaries are accessible with default path" {
  assert_in_path "runsvdir"
  assert_in_path "runsv"
  assert_in_path "sv"
  assert_in_path "svlogd"
  assert_in_path "chef-client"
  assert_in_path "chef-init"
}
