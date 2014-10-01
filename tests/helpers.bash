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

if [ "$FIXTURE_ROOT" != "$BATS_TEST_DIRNAME/fixtures" ]; then
  export FIXTURE_ROOT="$BATS_TEST_DIRNAME/fixtures"
  export CHEF_INIT_LOG="$BATS_TMPDIR/chef-init-log"
  export CHEF_SERVER_LOG="$BATS_TMPDIR/chef-server-log"
fi

chef_init_bootstrap() {
  chef-init --bootstrap --config "$FIXTURE_ROOT/client.rb" "$@" --node-name tester
}

#
# Start the chef-init --onboot process in the background
#
# @param [Stirng] $1
#   Which configuration file to use: zero or client
# @param [String] $2
#   Which first-boot.json to use: passing or failing
#
start_chef_init() {
  chef-init --config "$FIXTURE_ROOT/client.rb" "$@" >"$CHEF_INIT_LOG" &
  echo "$!" >"$BATS_TMPDIR/chef-init.pid"
  sleep 5
}

#
# Stop the chef-init --onboot process that is running in the background
#
stop_chef_init() {
  chef_init_pid=$(cat "$BATS_TMPDIR/chef-init.pid")
  kill -SIGTERM "$chef_init_pid"
  wait "$chef_init_pid" 2>/dev/null
  rm -rf "$BATS_TMPDIR/chef-init.pid"
  sleep 7
}

#
# Start the temporary Chef Server
#
start_chef_server() {
  cp -R "$FIXTURE_ROOT/chef_data" "$BATS_TMPDIR/chef_data"
  knife serve --chef-repo-path "$BATS_TMPDIR/chef_data" \
    --chef-zero-host "127.0.0.1" \
    --chef-zero-port "8889" \
    --config "$FIXTURE_ROOT/client.rb" >"$CHEF_SERVER_LOG" &
  echo "$!" >"$BATS_TMPDIR/chef-server.pid"
}

#
# Stop the temporary Chef Server
#rm -rf "$BATS_TMPDIR/chef_data"
#
stop_chef_server() {
  chef_server_pid=$(cat "$BATS_TMPDIR/chef-server.pid")
  kill -SIGINT "$chef_server_pid"
  wait "$chef_server_pid" 2>/dev/null
  rm -rf "$BATS_TMPDIR/chef-server.pid"
}

#
# Return whether the given process is running.
#
# @param [String] $1
#   The name of the process to look for.
#
find_process() {
  # encapsulate last character in [] to ignore the grep process
  local name=$(echo "$1" | sed "s/\(.\)$/[\1]/")
  echo "Looking for $name"
  echo "------Process Table------"
  ps -ef
  ps -ef | grep "$name"
}

refresh_tmpdata() {
  rm -rf "$BATS_TMPDIR/chef_data"
  cp -R "$FIXTURE_ROOT/chef_data" "$BATS_TMPDIR/chef_data"
}

#
# Teardown tasks
#
teardown_common() {
  pkill "chef-init --bootstrap"
  pkill "chef-init --onboot"
  rm -rf /opt/chef/service/*
  rm -rf /opt/chef/sv/*
  #rm -rf "$CHEF_INIT_LOG"
  rm -rf /var/log/chef-init*
}

#
# @param [Stirng] $1
#   The location of the file
# @param [String] $2
#   The contents to look for
#
assert_file_contains() {
  local content=$(cat "$1")
  local expected="$2"
  echo "$content" | $(type -p ggrep grep | head -1) -F "$expected" >/dev/null || {
    { echo "expected $1 to contain $expected"
      echo "actual: $content"
    } | flunk
  }
}

#
# Assert that none of the test processes are running
#
assert_cleanup_success() {
  refute_process_running "runsvdir -P /opt/chef/service"
  refute_process_running "runsv chef-init-test-auto"
  refute_process_running "chef-init-test-auto"
  refute_process_running "runsv chef-init-test-manual"
  refute_process_running "chef-init-test-manual"
}


#
# Assert that the given binary is in the path
#
# @param [String] $1
#   The name of the binary
#
assert_in_path() {
  run which "$1"
  assert_success
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

#
# Assert that the process is running
#
# @param [String] $1
#   The name of the process
#
assert_process_running() {
  run find_process "$1"
  assert_success
}

############
# The following assertion helpers were taken from sstephenson/ruby-build
############

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
