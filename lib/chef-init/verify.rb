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
      run_onboot_tests
      cleanup_test_environment

      if ChefInit::Test.did_pass?
        ChefInit::Log.info("All tests passed.")
      else
        failed_test_string = ChefInit::Test.failed_tests.each { |t|
          "\t{t}" }.join("\n")

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

      #
      # Does a failed chef run cause chef-init --bootstrap to exit with a non-zero?
      #
      fail_chef_run = ChefInit::Test.new("failing chef-client exit codes are honored")

      failing_command = Mixlib::ShellOut.new("#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "-c #{tempdir}/zero.rb " \
        "-j #{tempdir}/bad-first-boot.json " \
        "--log_level #{ChefInit::Log.level}")

      failing_command.run_command

      if failing_command.exitstatus == 0
        fail_chef_run.fail "bootstrap: chef-init does not honor failing exit code from chef-client"
        puts failing_command.stdout
        ChefInit::Log.info("Mixlib::ShellOut Exit Code: #{failing_command.exitstatus}")
      else
        fail_chef_run.pass
      end

      # Cleanup
      reset_tempdir

      #
      # Does a passing chef run cause chef-init --bootstrap to exit with a zero?
      #
      pass_chef_run = ChefInit::Test.new("passing chef-client exit codes are honored")

      successful_command = Mixlib::ShellOut.new("#{omnibus_bin_dir}/chef-init " \
        '--bootstrap ' \
        "-c #{tempdir}/zero.rb " \
        "-j #{tempdir}/good-first-boot.json " \
        "--log_level #{ChefInit::Log.level}")

      successful_command.run_command

      if successful_command.exitstatus == 0
        pass_chef_run.pass
      else
        pass_chef_run.fail "bootstrap: chef-init does not honor passing exit code from chef-client"
        puts successful_command.stdout
      end

      # Cleanup
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
    end

    ##
    # --onboot tests
    #   It should launch the chef-init --onboot process and then run the tests
    #   while it is still running. After the tests have run, it should quit
    #   chef-init --onboot.
    #
    def run_onboot_tests

      master_process = Process.spawn("#{omnibus_bin_dir}/chef-init --onboot "\
        "-c #{tempdir}/zero.rb " \
        "-j #{tempdir}/good-first-boot.json " \
        "--log_level #{ChefInit::Log.level}")

      # Does it start the runit process?
      runsvdir_started = ChefInit::Test.new("runsvdir started")
      output = system_command("ps aux | grep runsvdi[r]")
      unless output.stdout.empty?
        runsvdir_started.pass
      else
        runsvdir_started.fail "onboot: runsvdir did not start"
      end

      # Do services start?
      enabled_services_started = ChefInit::Test.new("enabled services started")
      output = system_command("ps aux | grep chef-init-tes[t]")
      unless output.stdout.empty?
        enabled_services_started.pass
      else
        enabled_services_started.fail "onboot: services did not start"
      end

      # Cleanup
      Process.kill("HUP", master_process)
      FileUtils.rm_rf('/opt/chef/sv')
      FileUtils.rm_rf('/opt/chef/service')
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
      clear_tempdir
    end

    def reset_tempdir
      clear_tempdir
      FileUtils.mkdir_p(tempdir)
      FileUtils.cp_r File.expand_path(File.dirname(__FILE__) + "../../../data") + "/.", tempdir
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
