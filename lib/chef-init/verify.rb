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
require 'chef-init/process'
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

    # Check whether or not the specified file does or does not exist (based
    # on the expected value). If it fails, we will print out the specified
    # error message.
    #
    # @param file [String] the name of the file
    # @param expected_value [TrueClass,FalseClass] whether we expect the file to exist
    # @param error_msg [String] the message to print if the test fails
    def test_file(file, expected_value, error_msg)
      if ::File.exist?(file) == expected_value
        pass
      else
        fail error_msg
      end
    end

    # Check whether or not the command returns the expected exit status.
    #
    # @param cmd [String] the command to run
    # @param expected_value [Integer] what exit status we expect
    # @param error_msg [String] the message to print if the test fails
    def test_cmd(cmd, expected_value, error_msg)
      output = system_command(cmd)
      if output.exitstatus == expected_value
        pass
      else
        fail error_msg

        ChefInit::Log.error("Expected `#{expected_value}` but received `#{output.exitstatus}`")
        ChefInit::Log.error("====== Command Output ======")
        puts output.stdout
      end
    end

    # Checks to see if a process is running. If it raises an exception that means it could
    # not be found. If that was the desired action, then pass it. Otherwise fail. If it doesn't
    # raise
    #
    # @param process [String] the regex string representing the process to look for
    # @param expected_value [TrueClass,FalseClass] whether the existence of the process
    #     indicates success or failure
    # @param error_msg [String] the message to print out if the test fails
    def test_ps(process, expected_value, error_msg)
      found = true
      begin
        ChefInit::Process.running?(process)
      rescue ChefInit::Exceptions::ProcessNotFound => e
        found = false
      ensure
        if found == expected_value then pass else fail error_msg end
      end
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

    # Run the verification tests
    def run
      binaries_exist?
      binaries_run?
      run_bootstrap_tests
      run_onboot_tests

      if ChefInit::Test.did_pass?
        ChefInit::Log.info("#{ChefInit::Test.num_tests_passed} tests passed.")
        exit true
      else
        failed_test_string = ChefInit::Test.failed_tests.each { |t|
          "\t #{t}" }.join("\n")

        ChefInit::Log.fatal("Tests failed:\n#{failed_test_string}")
        exit false
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
        file_exists.test_file(file, true, "#{file} does not exist")
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
        command_runs.test_cmd(command, 0, "`#{command}` does not exit with 0")
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

      chefinit = ChefInit::Process.new(chef_init_cmd)
      chefinit.launch

      # Wait a bit for chef-client to run
      wait_for_ccr_finish

      # Does it start the runit process?
      runsvdir_started = ChefInit::Test.new("runsvdir started")
      runsvdir_started.test_ps("runsvdir -P /opt/chef/service", true, "onboot: runsvdir did not start")

      # Do services start?
      enabled_services_started = ChefInit::Test.new("enabled services started")
      enabled_services_started.test_ps("chef-init-test", true, "onboot: services did not start")

      # Cleanup
      chefinit.kill
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

      chefinit_cmd = "#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "--config #{tempdir}/zero.rb " \
        "--json-attributes #{tempdir}/bad-first-boot.json " \
        "--log_level #{ChefInit::Log.level}"

      fail_chef_run.test_cmd(chefinit_cmd, 1, "bootstrap: chef-init does not " \
        "honor failing exit code from chef-client")

      check_for_leftover_supervisor_processes("failing bootstrap")

      # Cleanup
      ChefInit::Process.kill(chefinit_cmd)
      cleanup_test_environment
    end

    #
    # Passing chef-init --boostrap run
    #
    def passing_bootstrap_run
      setup_test_environment

      pass_chef_run = ChefInit::Test.new("bootstrap: passing chef-client exit" \
        " codes are honored")

      chefinit_cmd = "#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "--config #{tempdir}/zero.rb " \
        "--json-attributes #{tempdir}/good-first-boot.json " \
        "--log_level warn"

      pass_chef_run.test_cmd(chefinit_cmd, 0, "bootstrap: chef-init does not honor passing exit" \
        " code from chef-client")

      check_for_leftover_supervisor_processes("successful bootstrap")

      # Cleanup
      ChefInit::Process.kill(chefinit_cmd)
      cleanup_test_environment
    end

    ####
    # Helper Methods
    ####

    #
    # Make sure that no supervisor processes are left over after exit
    #
    def check_for_leftover_supervisor_processes(tag)
      runsvdir_check = ChefInit::Test.new("#{tag} - runsvdir process is cleaned up")
      runsvdir_check.test_ps("runsvdir -P /opt/chef/service", true, "#{tag} - runsvdir is still running")

      runsv_check = ChefInit::Test.new("#{tag} - runsv process is cleaned up")
      runsv_check.test_ps("runsv chef-init", true, "#{tag} - runsv is still running")

      test_tool_check = ChefInit::Test.new("#{tag} - chef-init-test process is cleaned up")
      test_tool_check.test_ps("chef-init-test", true, "#{tag} - chef-init-test process is still running")
    end

    def wait_for_ccr_finish
      tries = 0
      while ChefInit::Process.running?("chef-client") && tries < 3
        tries += 1
        sleep tries*5
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
