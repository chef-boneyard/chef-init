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

require 'chef/resource/file'
require 'chef/provider/file'
require 'chef/provider/service'
require 'chef/mixin/shell_out'
require 'chef/mixin/language'
require 'chef-init/helpers'

module ChefInit
  class Supervisor
    class Runit < Chef::Provider::Service
      # container_service
      include Chef::Mixin::ShellOut
      include ChefInit::Helpers

      def initialize(*args)
        super
        @service_link = nil
        @service_endpoint = nil
        @new_resource.supports[:status] = true
      end

      def load_current_resource
        @current_resource = Chef::Resource::Service.new(new_resource.name)
        @current_resource.service_name(new_resource.service_name)

        # Check the current status of the runit service
        @current_resource.running(running?)
        @current_resource.enabled(enabled?)
        @current_resource
      end

      #
      # Override Service Actions
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

      def running?
        cmd = shell_out("#{sv_bin} status #{service_dir_name}")
        (cmd.stdout =~ /^run:/ && cmd.exitstatus == 0)
      end

      def enabled?
        ::File.exists?(::File.join(service_dir_name, 'run'))
      end

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

      def sv_bin
        ::File.join(omnibus_embedded_bin_dir, "sv")
      end

      def down_file
        return @down_file unless @down_file.nil?
        @down_file = Chef::Resource::File.new(::File.join(service_dir_name, 'down'), run_context)
        @down_file
      end
    end
  end
end
