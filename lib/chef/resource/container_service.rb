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
    #
    # This is a monkeypatch to the Service resource. It serves as the glue
    # between the existing +service+ resource and the needs of the container
    # service environment.
    #
    class Service

      #
      # We alias the original Service resource's initialize statement so that
      # we can overwrite it with our own.
      #
      alias_method :orig_initialize, :initialize

      #
      # Create the +service+ resource object but then inspect the node object
      # looking for the +node[:container_service][service_name][:command]+ attribute.
      # If we find it, we override the backend provider with the included provider.
      # Currently, we only support the custom +runit+ provider but in the future
      # we may support others.
      #
      def initialize(name, run_context=nil)
        orig_initialize(name, run_context)

        if container_service_command_specified?
          Chef::Log.info("Provider for service[#{@service_name}] has been " \
            "replaced with Chef::Provider::ContainerService::Runit")
          @provider = Chef::Provider::ContainerService::Runit
        end
      end

      #
      # Inspects the node object and returns whether or not it could find the
      # +node[:container_service][service_name][:command]+ node attribute.
      #
      # The +node[:container_service][service_name][:command]+ attribute will
      # hold the command the container_service provider needs in order to launch
      # the service.
      #
      # @return [Boolean]
      #
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
