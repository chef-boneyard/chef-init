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
  class Test
    @@failed_tests = []

    include ChefInit::Helpers

    def initialize(name)
      @name = name
    end

    def fail(msg)
      ChefInit::Log.error("#{@name}: fail")
      @@failed_tests << msg
    end

    def pass
      ChefInit::Log.info("#{@name}: pass")
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

    def run
      binaries_exist?
      binaries_run?
      setup_test_environment
      run_bootstrap_tests
      cleanup_bootstrap_environment
      run_onboot_tests
      cleanup_onboot_environment
      cleanup_test_environment

      if ChefInit::Test.did_pass?
        ChefInit::Log.info("All tests passed.")
      else
        failed_test_string = ChefInit::Test.failed_tests.each { |t| "\t{t}" }.join("\n")

        ChefInit::Log.fatal("Tests failed:\n#{failed_test_string}")
        exit 1
      end
    end


    # Check to make sure the necessary binaries exist
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
        file_exists = ChefInit::Test.new("checking for #{file}")
        if File.exists?(file)
          file_exists.pass
        else
          file_exists.fail "#{file} does not exist"
        end
      end
    end

    # Check to make sure the necessary commands run successfully (libraries load)
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

    ##
    # --bootstrap tests
    #
    def run_bootstrap_tests
      ChefInit::Log.info("-" * 20)
      ChefInit::Log.info("Running tests for `chef-init --bootstrap`")
      ChefInit::Log.info("-" * 20)

      # Does a failed chef run cause chef-init --bootstrap to exit with a non-zero?
      chef_exit_codes = ChefInit::Test.new("chef-client exit codes are honored")
      ChefInit::Log.debug("Attempting to run command: #{omnibus_bin_dir}/chef-init --bootstrap -c #{tempdir}/zero.rb -j #{tempdir}/bad-first-boot.json")

      failing_command = system_command("#{omnibus_bin_dir}/chef-init --bootstrap -c #{tempdir}/zero.rb -j #{tempdir}/bad-first-boot.json --log_level debug")
      ChefInit::Log.debug(failing_command.stderr)
      ChefInit::Log.debug(failing_command.stdout)
      if output.exitstatus == 0
        chef_exit_codes.fail "bootstrap: chef-init does not honor exit code from chef-client"
      else
        chef_exit_codes.pass
      end

      successful_command = system_command("#{omnibus_bin_dir}/chef-init --bootstrap -c #{tempdir}/zero.rb -j #{tempdir}/bad-first-boot.json --log_level debug")
      ChefInit::Log.debug(failing_command.stderr)
      ChefInit::Log.debug(failing_command.stdout)
      if output.exitstatus == 0
        chef_exit_codes.pass
      else
        chef_exit_codes.fail "bootstrap: chef-init does not honor exit code from chef-client"
      end
    end

    ##
    # --onboot tests
    #
    def run_onboot_tests
      ChefInit::Log.info("-" * 20)
      ChefInit::Log.info("Running tests for `chef-init --onboot`")
      ChefInit::Log.info("-" * 20)
      ChefInit::Log.debug("Attempting to run command: #{omnibus_bin_dir}/chef-init --onboot -c #{tempdir}/zero.rb -j #{tempdir}/first-boot.json --log_level debug")
      output = system_command("#{omnibus_bin_dir}/chef-init --onboot -c #{tempdir}/zero.rb -j #{tempdir}/good-first-boot.json --log_level debug")
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)

      # Does it start the runit process?
      runsvdir_started = ChefInit::Test.new("runsvdir started")
      output = system_command("ps aux | grep runsvdi[r]")
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)
      unless output.stdout.empty?
        runsvdir_started.pass
      else
        runsvdir_started.fail "onboot: runsvdir did not start"
      end

      # Do services start?
      enabled_services_started = ChefInit::Test.new("enabled services started")
      output = system_command("ps aux | grep chef-init-tes[t]")
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)
      unless output.stdout.empty?
        enabled_services_started.pass
      else
        enabled_services_started.fail "onboot: services did not start"
      end
    end

    ##
    # Helper Methods
    #
    def setup_test_environment
      # Copy the fixture data into the tempdir
      FileUtils.cp_r File.expand_path(File.dirname(__FILE__) + "../../../data") + "/.", tempdir
    end

    def cleanup_bootstrap_environment
      ChefInit::Log.debug("Cleaning up bootstrap environment")
      output = system_command("sudo /opt/chef/embedded/bin/sv shutdown /opt/chef/service/*")
      # sv shutdown allows 7 seconds for services to shut down, giving it 10
      sleep(10)
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
    end

    def cleanup_onboot_environment
      ChefInit::Log.debug("Cleaning up onboot environment")
      output = system_command("sudo /opt/chef/embedded/bin/sv shutdown /opt/chef/service/*")
      # sv shutdown allows 7 seconds for services to shut down, giving it 10
      sleep(10)
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
    end

    def cleanup_test_environment
      ChefInit::Log.debug("Cleaning up testing environment")
      FileUtils.rm_rf(File.join(tempdir, 'zero.rb'))
      FileUtils.rm_rf(File.join(tempdir, 'first-boot.json'))
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
      clear_tempdir
    end

    def reset_tempdir
      clear_tempdir
      FileUtils.mkdir_p(tempdir)
    end

    def clear_tempdir
      FileUtils.rm_rf(tempdir)
      @tmpdir = nil
    end

    def tempdir
      @tmpdir ||= Dir.mktmpdir("chef")
      File.realpath(@tmpdir)
    end
  end
end
