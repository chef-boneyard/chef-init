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

require 'chef/resource/link'
require 'chef/provider/link'
require 'chef/resource/file'
require 'chef/provider/file'
require 'chef/resource/directory'
require 'chef/provider/directory'
require 'chef/provider/container_service'

class Chef
  class Provider
    class ContainerService
      class Runit < Chef::Provider::ContainerService

        attr_reader :command

        def initialize(name, run_context=nil)
          super
          @new_resource.supports[:status] = true
          @staging_dir = nil
          @down_file = nil
          @run_script = nil
          @log_dir = nil
          @log_main_dir = nil
          @log_run_script = nil
          @service_dir_link = nil
          @command = node["container_service"][new_resource.service_name]["command"]
        end

        def load_current_resource
          @current_resource = Chef::Resource::Service.new(new_resource.name)
          @current_resource.service_name(new_resource.service_name)

          setup

          # Check the current status of the runit service
          @current_resource.running(running?)
          @current_resource.enabled(enabled?)
          @current_resource
        end

        ##
        # Setup Action
        #
        def setup
          Chef::Log.debug("Creating service staging directory for #{new_resource.service_name}")
          staging_dir.run_action(:create)

          Chef::Log.debug("Creating down file for #{new_resource.service_name}")
          down_file.run_action(:create)

          Chef::Log.debug("Creating run script for #{new_resource.service_name}")
          run_script.run_action(:create)

          Chef::Log.debug("Creating /var/log directory for #{new_resource.service_name}")
          log_dir.run_action(:create)

          Chef::Log.debug("Creating log dir for #{new_resource.service_name}")
          log_main_dir.run_action(:create)

          Chef::Log.debug("Creating log run script for #{new_resource.service_name}")
          log_run_script.run_action(:create)

          Chef::Log.debug("Linking staging directory to service directory for #{new_resource.service_name}")
          service_dir_link.run_action(:create)
        end


        ##
        # Service Resource Overrides
        #
        def enable_service
          down_file.run_action(:delete)
        end

        def disable_service
          down_file.run_action(:create)
          shell_out("#{sv_bin} down #{service_dir_name}")
          Chef::Log.debug("#{new_resource} down")
        end

        def start_service
          wait_for_service_enable
          shell_out!("#{sv_bin} start #{service_dir_name}")
        end

        def stop_service
          shell_out!("#{sv_bin} stop #{service_dir_name}")
        end

        def restart_service
          shell_out!("#{sv_bin} restart #{service_dir_name}")
        end

        def reload_service
          shell_out!("#{sv_bin} force-reload #{service_dir_name}")
        end

        ##
        # Helper Methods for Service Override
        #
        def running?
          cmd = shell_out("#{sv_bin} status #{service_dir_name}")
          (cmd.stdout.match(/^run:/) && cmd.exitstatus == 0) ? true : false
        end

        def enabled?
          !::File.exists?(::File.join(service_dir_name, 'down'))
        end

        ##
        # General Helpers Methods
        #
        def wait_for_service_enable
          Chef::Log.debug("waiting until named pipe #{service_dir_name}/supervise/ok exists.")
          until ::FileTest.pipe?("#{service_dir_name}/supervise/ok")
            sleep 1
            Chef::Log.debug('.')
          end

          Chef::Log.debug("waiting until named pipe #{service_dir_name}/log/supervise/ok exists.")
          until ::FileTest.pipe?("#{service_dir_name}/log/supervise/ok")
            sleep 1
            Chef::Log.debug('.')
          end
        end

        def service_dir_name
          ::File.join(omnibus_root, "service", new_resource.service_name)
        end

        def staging_dir_name
          ::File.join(omnibus_root, "sv", new_resource.service_name)
        end

        def sv_bin
          ::File.join(omnibus_embedded_bin_dir, "sv")
        end

        ##
        # Helper Methods for Supervisor Setup
        #
        def run_script_content
          "#!/bin/sh
exec 2>&1
exec #{@command} 2>&1"
        end

        def log_run_script_content
          "#!/bin/sh
exec svlogd -tt /var/log/#{new_resource.service_name}"
        end

        ##
        # Helper Methods that control Chef Resources
        #
        def staging_dir
          return @staging_dir unless @staging_dir.nil?
          @staging_dir = Chef::Resource::Directory.new(staging_dir_name, run_context)
          @staging_dir.recursive(true)
          @staging_dir.mode(00755)
          @staging_dir
        end

        def run_script
          return @run_script unless @run_script.nil?
          @run_script = Chef::Resource::File.new(::File.join(staging_dir_name, 'run'), run_context)
          @run_script.content(run_script_content)
          @run_script.mode(00755)
          @run_script
        end

        def log_dir
          return @log_dir unless @log_dir.nil?
          @log_dir = Chef::Resource::Directory.new("/var/log/#{new_resource.service_name}", run_context)
          @log_dir.recursive(true)
          @log_dir.mode(00755)
          @log_dir
        end

        def log_main_dir
          return @log_main_dir unless @log_main_dir.nil?
          @log_main_dir = Chef::Resource::Directory.new(::File.join(staging_dir_name, 'log'), run_context)
          @log_main_dir.recursive(true)
          @log_main_dir.mode(00755)
          @log_main_dir
        end

        def log_run_script
          return @log_run_script unless @log_run_script.nil?
          @log_run_script = Chef::Resource::File.new(::File.join(staging_dir_name, 'log', 'run'), run_context)
          @log_run_script.content(log_run_script_content)
          @log_run_script.mode(00755)
          @log_run_script
        end

        def service_dir_link
          return @service_dir_link unless @service_dir_link.nil?
          @service_dir_link = Chef::Resource::Link.new(::File.join(service_dir_name), run_context)
          @service_dir_link.to(staging_dir_name)
          @service_dir_link
        end

        def down_file
          return @down_file unless @down_file.nil?
          @down_file = Chef::Resource::File.new(::File.join(staging_dir_name, 'down'), run_context)
          @down_file.backup(false)
          @down_file
        end
      end
    end
  end
end
