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

require 'chef-init/helpers'
require 'chef-init/log'
require 'fileutils'
require 'tmpdir'

module ChefInit
  # A class to handle/store test case data
  class Test
    @@test_count = 0
    @@failed_tests = []

    include ChefInit::Helpers

    def initialize(name)
      @name = name
      @@test_count += 1
    end

    def fail(msg)
      ChefInit::Log.error("#{@name}: fail")
      @@failed_tests << msg
    end

    def pass
      ChefInit::Log.info("#{@name}: pass")
    end

    def self.num_tests_passed
      "#{@@test_count - @@failed_tests.length}/#{@@test_count}"
    end

    def self.did_pass?
      @@failed_tests.empty?
    end

    def self.failed_tests
      @@failed_tests
    end
  end

  class Verify

    include ChefInit::Helpers

    #
    # Run the verification tests
    #
    def run
      binaries_exist?
      binaries_run?
      run_bootstrap_tests
      run_onboot_tests

      if ChefInit::Test.did_pass?
        ChefInit::Log.info("#{ChefInit::Test.num_tests_passed} tests passed.")
      else
        failed_test_string = ChefInit::Test.failed_tests.each { |t|
          "\t #{t}" }.join("\n")

        ChefInit::Log.fatal("Tests failed:\n#{failed_test_string}")
        exit 1
      end
    end

    #
    # Check to make sure the necessary binaries exist
    #
    def binaries_exist?
      files = [
        File.join(omnibus_embedded_bin_dir, 'runsvdir'),
        File.join(omnibus_embedded_bin_dir, 'sv'),
        File.join(omnibus_bin_dir, 'chef-init'),
        '/usr/bin/chef-init',
        File.join(omnibus_bin_dir, 'chef-client'),
        '/usr/bin/chef-client'
      ]

      files.each do |file|
        file_exists = ChefInit::Test.new("file '#{file}' exists")
        if File.exists?(file)
          file_exists.pass
        else
          file_exists.fail "#{file} does not exist"
        end
      end
    end

    #
    # Check to make sure the necessary commands run successfully (libraries load)
    #
    def binaries_run?
      commands = [
        "#{omnibus_bin_dir}/chef-init --version",
        "/usr/bin/chef-init --version",
        "#{omnibus_bin_dir}/chef-client --version",
        "/usr/bin/chef-client --version"
      ]

      commands.each do |command|
        command_runs = ChefInit::Test.new("command `#{command}` runs")
        output = system_command(command)
        if output.exitstatus == 0
          command_runs.pass
        else
          command_runs.fail "`#{command}` does not exit with 0"
        end
      end

    end

    #
    # bootstrap tests
    #
    def run_bootstrap_tests
      # Does a failed chef run cause chef-init --bootstrap to exit with a non-zero?
      failing_bootstrap_run

      # Does a passing chef run cause chef-init --bootstrap to exit with a zero?
      passing_bootstrap_run
    end

    #
    # onboot tests
    #   It should launch the chef-init --onboot process and then run the tests
    #   while it is still running. After the tests have run, it should quit
    #   chef-init --onboot.
    #
    def run_onboot_tests
      setup_test_environment

      chef_init_cmd = "#{omnibus_bin_dir}/chef-init" \
        " --onboot" \
        " --log_level #{ChefInit::Log.level}" \
        " --config #{tempdir}/zero.rb" \
        " --json-attributes #{tempdir}/good-first-boot.json"

      Process.spawn(chef_init_cmd, out:"#{tempdir}/chef-init-log")

      # Wait a bit for chef-client to run
      sleep 10

      # Does it start the runit process?
      runsvdir_started = ChefInit::Test.new("runsvdir started")
      output = system_command("ps aux | grep runsvdi[r]")
      unless output.stdout.empty?
        runsvdir_started.pass
      else
        runsvdir_started.fail "onboot: runsvdir did not start"
        puts output.stdout
      end

      # Do services start?
      enabled_services_started = ChefInit::Test.new("enabled services started")
      output = system_command("ps aux | grep chef-init-tes[t]")
      unless output.stdout.empty?
        enabled_services_started.pass
      else
        enabled_services_started.fail "onboot: services did not start"
        puts output.stdout
      end

      # Cleanup
      system_command("pkill -TERM -f '#{chef_init_cmd}'")

      # wait for things to cleanup
      sleep 15
      cleanup_test_environment

      check_for_leftover_supervisor_processes("onboot")
    end

    ####
    # Bootstrap Tests
    ####

    #
    # Failing chef-init --bootstrap run
    #
    def failing_bootstrap_run
      setup_test_environment

      fail_chef_run = ChefInit::Test.new("bootstrap: failing chef-client exit" \
        " codes are honored")

      failing_command = system_command("#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "--config #{tempdir}/zero.rb " \
        "--json-attributes #{tempdir}/bad-first-boot.json " \
        "--log_level #{ChefInit::Log.level}")

      # Test to make sure that a non-zero exit code was returned
      if failing_command.exitstatus == 0
        fail_chef_run.fail "bootstrap: chef-init does not honor failing exit" \
          " code from chef-client"
        puts failing_command.stdout
      else
        fail_chef_run.pass
      end

      # Make sure that there are no leftover supervisor processes
      check_for_leftover_supervisor_processes("failing bootstrap")

      cleanup_test_environment
    end

    #
    # Passing chef-init --boostrap run
    #
    def passing_bootstrap_run
      setup_test_environment

      pass_chef_run = ChefInit::Test.new("bootstrap: passing chef-client exit" \
        " codes are honored")

      successful_command =system_command("#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "--config #{tempdir}/zero.rb " \
        "--json-attributes #{tempdir}/good-first-boot.json " \
        "--log_level warn")

      if successful_command.exitstatus == 0
        pass_chef_run.pass
      else
        pass_chef_run.fail "bootstrap: chef-init does not honor passing exit" \
          " code from chef-client"
        puts successful_command.stdout
      end

      # Make sure that there are no leftover supervisor processes
      check_for_leftover_supervisor_processes("successful bootstrap")

      cleanup_test_environment
    end

    ####
    # Helper Methods
    ####

    #
    # Make sure that no supervisor processes are left over after exit
    #
    def check_for_leftover_supervisor_processes(tag)
      # wait for a few seconds to let things close down
      sleep 5

      leftover_processes = ChefInit::Test.new("#{tag} - supervisor processes" \
        " are cleaned up")

      # Check to runsvdir
      runsvdir_check = system_command("ps aux | grep bin\/runsvdi[r]")
      runsv_check = system_command("ps aux | grep runs[v] chef\-init")
      test_tool_check = system_command("ps aux | grep chef-init-tes[t]")

      case
      when !runsvdir_check.stdout.empty?
        leftover_processes.fail "#{tag} - runsvdir is still running"
        puts runsvdir_check.stdout
      when !runsv_check.stdout.empty?
        leftover_processes.fail "#{tag} - runsv is still running"
        puts runsv_check.stdout
      when !test_tool_check.stdout.empty?
        leftover_processes.fail "#{tag} - chef-init-test is still running"
        puts test_tool_check.stdout
      else
        leftover_processes.pass
      end
    end

    def setup_test_environment
      FileUtils.mkdir_p(tempdir)
      FileUtils.cp_r "#{data_path}/.", tempdir
    end

    def cleanup_test_environment
      clear_tempdir
    end

    def clear_tempdir
      FileUtils.rm_rf(tempdir)
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
      @tmpdir = nil
    end

    def tempdir
      @tmpdir ||= Dir.mktmpdir("chef")
      File.realpath(@tmpdir)
    end
  end
end
