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

require 'chef/resource/supervisor'
require 'chef/provider/supervisor/runit'

class Chef
  module DSL
    module Recipe

      # Special thanks for Dan Deleo
      def service(name, &block) 
        source_line = caller[0]
        command = valid_supervisor_command_specified?(name)
        unless command.nil? 
          r = declare_resource(:supervisor, name, source_line, &block)
          r.command(command)
        else
          declare_resource(:service, name, source_line, &block)
        end
      end

      def valid_supervisor_command_specified?(service_name)
        if node["container_service"].key?(service_name)
          return node["container_service"][service_name]["command"]
        else
          return nil
        end
      end
    end
  end
end
