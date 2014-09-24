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

chef_init_bootstrap() {
  chef-init --bootstrap --config "$BATS_TEST_DIRNAME/fixtures/$1.rb" --json-attributes "$BATS_TEST_DIRNAME/fixtures/$2-first-boot.json"
}

#
# Start the chef-init --onboot process
#
# @param [Stirng] $1
#   Which configuration file to use: zero or client
#
start_chef_init() {
  chef-init --onboot --config $BATS_TEST_DIRNAME/fixtures/$1.rb --json-attributes $BATS_TEST_DIRNAME/fixtures/passing-first-boot.json
}

#
# Kill the chef-init --onboot process
#
stop_chef_init() {
  pkill 'chef-init'
}

#
# Start the temporary Chef Server
#
start_chef_server() {
  chef-zero
}

#
# Seed the temporary Chef Server with data
#
seed_chef_server() {
  knife upload $BATS_TEST_DIRNAME/fixtures/chef_data
}

#
# Stop the temporary Chef Server
#
stop_chef_server() {
  pkill 'chef-zero'
}

#
# Return whether the given process is running
#
# @param [String] $1
#   The name of the process to look for.
#
find_process() {
  ps -ef | grep "$1"
}

#
# Teardown tasks
#   * Cleanup /opt/chef/service
#
teardown() {
  rm -rf /opt/chef/service/*
  rm -rf /opt/chef/sv/*
}

#
# Assert that none of the test processes are running
#
assert_cleanup_success() {
  refute_process_running "runsvdi[r] -P /opt/chef/service"
  refute_process_running "runsv chef-init-test-aut[o]"
  refute_process_running "chef-init-logger --service-name chef-init-test-aut[o]"
  refute_process_running "chef-init-test-aut[o]"
  refute_process_running "runsv chef-init-test-manua[l]"
  refute_process_running "chef-init-test-manua[l]"
}


#
# Assert that the process is not running.
#
# @param [String] $1
#   The name of the process
#
refute_process_running() {
  run find_process "$1"
  assert_failure
}


############
# The following assertion helpers were taken from sstephenson/ruby-build
############

#
# Assert
assert() {
  if ! "$@"; then
    flunk "failed: $@"
  fi
}

flunk() {
  { if [ "$#" -eq 0 ]; then cat -
    else echo "$@"
    fi
  }
  return 1
}

#
# Assert that the most recent command should pass
#
assert_success() {
  if [ "$status" -ne 0 ]; then
    { echo "command failed with exit status $status"
      echo "output: $output"
    } | flunk
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

#
# Assert that the most recent command should fail
#
assert_failure() {
  if [ "$status" -eq 0 ]; then
    flunk "expected failed exit status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

#
# Assert that t
assert_equal() {
  if [ "$1" != "$2" ]; then
    { echo "expected: $1"
      echo "actual:   $2"
    } | flunk
  fi
}

assert_output() {
  local expected
  if [ $# -eq 0 ]; then expected="$(cat -)"
  else expected="$1"
  fi
  assert_equal "$expected" "$output"
}

assert_output_contains() {
  local expected="$1"
  echo "$output" | $(type -p ggrep grep | head -1) -F "$expected" >/dev/null || {
    { echo "expected output to contain $expected"
      echo "actual: $output"
    } | flunk
  }
}
