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
require 'chef/provider/supervisor'
require 'chef/resource/file'
require 'chef/provider/file'
require 'chef/resource/directory'
require 'chef/provider/directory'
require 'chef-init/exceptions'

class Chef
  class Provider
    class Supervisor
      class Runit < Chef::Provider::Supervisor

        def initialize(*args)
          super
          @service_dir = nil
          @down_file = nil
          @run_script = nil
          @log_dir = nil
          @log_main_dir = nil
          @log_run_script = nil
        end

        def load_current_resource
          @current_resource = Chef::Resource::RunitSupervisor.new(new_resource.name) 
          @current_resource.service_name(new_resource.service_name)
          @current_resource.enabled(::File.exist?(::File.join(service_dir_name, 'run')))
          @current_resource
        end

        def define_resource_requirements
          requirements.assert(:enable) do |a|
            a.assertion do 
              ::File.exists?(new_resource.sv_bin) && ::File.executable?(new_resource.sv_bin)
            end
            a.failure_message(Chef::Exceptions::Supervisor, "#{new_resource.sv_bin} does not exist or is not executable")
            a.whyrun("Supervisor binary #{new_resource.sv_bin} does not exist.") do
              @status_load_success = false
            end
          end
        end

        def enable_supervisor
          Chef::Log.debug("Creating service directory for #{new_resource.service_name}")
          service_dir.run_action(:create)

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
        end

        private

        def service_dir_name
          ::File.join(new_resource.service_dir, new_resource.service_name)
        end

        def run_script_content
          "#!/bin/sh
  exec 2>&1
  exec #{new_resource.command} 2>&1"
        end

        def log_run_script_content
          "#!/bin/sh
  exec svlogd -tt /var/log/#{new_resource.service_name}"
        end

        #
        # Helper Resources
        #
        def service_dir
          return @service_dir unless @service_dir.nil?
          @service_dir = Chef::Resource::Directory.new(service_dir_name, run_context)
          @service_dir.recursive(true)
          @service_dir.mode(00755)
          @service_dir
        end

        def down_file
          return @down_file unless @down_file.nil?
          @down_file = Chef::Resource::File.new(::File.join(service_dir_name, 'down'), run_context)
          @down_file.mode(00755)
          @down_file
        end
          
        def run_script
          return @run_script unless @run_script.nil?
          @run_script = Chef::Resource::File.new(::File.join(service_dir_name, 'run'), run_context)
          @run_script.content(run_script_content)
          @run_script.mode(00755)
          @run_script
        end

        def log_dir
          return @log_dir unless @log_dir.nil?
          @log_dir = Chef::Resource::Directory.new("/var/log/#{new_resource.service_name}", run_context)
          @log_dir.resursive(true)
          @log_dir.mode(00755)
          @log_dir
        end

        def log_main_dir
          return @log_main_dir unless @log_main_dir.nil?
          @log_main_dir = Chef::Resource::Directory.new(::File.join(service_dir_name, 'log'), run_context)
          @log_main_dir.recursive(true)
          @log_main_dir.mode(00755)
          @log_main_dir
        end

        def log_run_script
          return @log_run_script unless @log_run_script.nil?
          @log_run_script = Chef::Resource::File.new(::File.join(service_dir_name, 'log', 'run'), run_context)
          @log_run_script.content(log_run_script_content)
          @log_run_script.mode(00755)
          @log_run_script
        end
        
      end
    end
  end
end
