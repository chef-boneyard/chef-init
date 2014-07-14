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
      ChefInit::Log.debug("Attempting to run command: #{omnibus_bin_dir}/chef-init --bootstrap -c #{tempdir}/zero.rb -j #{tempdir}/first-boot.json")
      system_command("#{omnibus_bin_dir}/chef-init --bootstrap -c #{tempdir}/zero.rb -j #{tempdir}/first-boot.json")
    end

    ##
    # --onboot tests
    #
    def run_onboot_tests
      ChefInit::Log.info("-" * 20)
      ChefInit::Log.info("Running tests for `chef-init --onboot`")
      ChefInit::Log.info("-" * 20)
      ChefInit::Log.debug("Attempting to run command: #{omnibus_bin_dir}/chef-init --onboot -c #{tempdir}/zero.rb -j #{tempdir}/first-boot.json")
      output = system_command("#{omnibus_bin_dir}/chef-init --onboot -c #{tempdir}/zero.rb -j #{tempdir}/first-boot.json --log_level debug")
      ChefInit::Log.debug(output.stderr)
      ChefInit::Log.debug(output.stdout)

      # give it a few seconds to setup
      sleep 10

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
      output = system_command("ps aux | grep polip[o]")
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
      # chef-init requirements
      File.open(File.join(tempdir, 'zero.rb'), "w") do |f|
        f.write(zero_config_string)
      end
      File.open(File.join(tempdir, 'first-boot.json'), "w") do |f|
        f.write(first_boot_string)
      end

      test_cookbook_path = File.join(tempdir, 'cookbooks')
      FileUtils.mkdir_p(test_cookbook_path)
      File.open(File.join(test_cookbook_path, 'metadata.rb'), "w") do |f|
        f.write(metadata_string)
      end

      test_recipe_path = File.join(test_cookbook_path, 'recipes')
      FileUtils.mkdir_p(test_recipe_path)
      File.open(File.join(test_recipe_path, 'default.rb'), "w") do |f|
        f.write(recipe_string)
      end
    end

    def cleanup_test_environment
      system_command("sudo /opt/chef/embedded/bin/sv shutdown /opt/chef/service/*")
      FileUtils.rm_rf(File.join(tempdir, 'zero.rb'))
      FileUtils.rm_rf(File.join(tempdir, 'first-boot.json'))
      FileUtils.rm_rf('/etc/chef/sv')
      FileUtils.rm_rf('/etc/chef/service')
      system_command("sudo apt-get -y remove --purge polipo")
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


    # I took these strings and put them into their own functions near the end so the code above is
    # a little easier to read.
    def zero_config_string
      <<-ZERO_CONFIG
require 'chef-init'

cookbook_path   ["#{tempdir}/cookbooks"]
ssl_verify_mode   :verify_peer
      ZERO_CONFIG
    end

    def first_boot_string
      <<-FIRST_BOOT
{
  "run_list": ["recipe[test]"],
  "container_service": {
    "polipo": {
      "command": "/usr/bin/polipo"
    }
  }
}
      FIRST_BOOT
    end

    def metadata_string
      <<-METADATA
name "test"

      METADATA
    end

    def recipe_string
      <<-RECIPE
package 'polipo' do
  action :install
end

service 'polipo' do
  action :start
end
      RECIPE
    end

  end
end