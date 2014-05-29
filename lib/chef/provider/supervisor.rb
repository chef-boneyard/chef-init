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

require 'chef/provider'

class Chef
  class Provider
    class Supervisor < Chef::Provider

      def whyrun_supported?
        true
      end

      def action_enable
        if @current_resource.enabled
          Chef::Log.debug("#{@new_resource} already enabled - nothing to do")
        else
          converge_by("enable supervisor #{@new_resource}") do
            enable_supervisor
            Chef::Log.info("#{@new_resource} enabled")
          end
        end
        @new_resource.enabled(true)
      end

      def action_disable
        if @current_resource.enabled
          converge_by("disable supervisor #{@new_resource}") do
            disable_supervisor
            Chef::Log.info("#{@new_resource} disabled")
          end
        else
          Chef::Log.debug("#{@new_resource} already disabled - nothing to do")
        end
        @new_resource.enabled(false)
      end

    end
  end
end
