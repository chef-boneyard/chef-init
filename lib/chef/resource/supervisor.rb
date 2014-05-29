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
require 'chef/resource'

class Chef
  class Resource
    class Supervisor < Chef::Resource

      state_attrs :enabled

      def initialize(name, run_context=nil)
        super
        @resource_name = :supervisor
        @supervisor_name = name
        @action = :enable
        @allowed_actions.push(:enabled, :disable)
        @enabled = nil
      end

      def supervisor_name(arg=nil)
        set_or_return(
          :supervisor_name,
          arg,
          :kind_of => [ String ]
        )
      end

      def enabled(arg=nil)
        set_or_return(
          :enabled,
          arg,
          :kind_of => [ TrueClass, FalseClass ]
        )
      end
    end
  end
end
