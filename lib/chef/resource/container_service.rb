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

require 'chef/provider/container_service/runit'

class Chef
  class Resource
    class ContainerService < Chef::Resource::Service

      provides :service, :on_platforms => :all

      def initialize(name, run_context = nil)
        super
        if container_service_command_specified?
          @provider = Chef::Provider::ContainerService::Runit
        end
      end

      def container_service_command_specified?
        if @run_context.node.key?("container_service")
          if @run_context.node["container_service"].key?(@service_name)
            return true
          else
            return false
          end
        else
          return false
        end
      end
    end
  end
end
