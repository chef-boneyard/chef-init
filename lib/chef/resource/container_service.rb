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

require 'chef/resource/service'
require 'chef/provider/container_service/runit'

class Chef
  class Resource
    class Service

      alias_method :orig_initialize, :initialize

      def initialize(name, run_context=nil)
        orig_initialize(name, run_context)

        if container_service_command_specified?
          Chef::Log.info("Provider for service[#{@service_name}] has been " \
            "replaced with Chef::Provider::ContainerService::Runit")
          @provider = Chef::Provider::ContainerService::Runit

        end
      end

      def provider(arg=nil)
          Chef::Provider::ContainerService::Runit
      end

      def provider=(str)
          @provider = Chef::Provider::ContainerService::Runit
      end


      def container_service_command_specified?
        unless @run_context.nil? || @run_context.node.nil?
          if @run_context.node.key?("container_service")
            if @run_context.node["container_service"].key?(@service_name)
              Chef::Log.debug("container_service command found for service[#{@service_name}].")
              return true
            else
              Chef::Log.debug("container_service command NOT found for service[#{@service_name}].")
              return false
            end
          else
            Chef::Log.debug("No container_service commands found.")
            return false
          end
        else
          return false
        end
      end
    end
  end
end
