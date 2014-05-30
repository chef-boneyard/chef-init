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
  class Resource
    class RunitSupervisor < Chef::Resource::Supervisor

      def initialize(name, run_context = nil)
        super
        @resource_name = :runit_supervisor
        @provider = Chef::Provider::Supervisor::Runit
        @service_name = name
        @command = nil
        @sv_bin = '/opt/chef/embedded/bin/sv'
        @service_dir = '/opt/chef/service'
        @sv_dir = '/opt/chef/sv'
      end

      def service_name(arg=nil)
        set_or_return(
          :service_name,
          arg,
          :kind_of => [ String ]
        )
      end

      def command(arg=nil)
        set_or_return(
          :command,
          arg,
          :kind_of => [ String ]
        )
      end

      def sv_bin(arg=nil)
        set_or_return(
          :sv_bin,
          arg,
          :kind_of => [ String ]
        )
      end

      def service_dir(arg=nil)
        set_or_return(
          :service_dir,
          arg,
          :kind_of => [ String ]
        )
      end

      def sv_dir(arg=nil)
        set_or_return(
          :sv_dir,
          arg,
          :kind_of => [ String ]
        )
      end
    end
  end
end
