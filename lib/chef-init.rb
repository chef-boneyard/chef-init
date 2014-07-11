#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
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

require 'chef/resource/container_service'

module ChefInit

  ##
  # This is a helper variable to use to set the node name when running chef-init.
  # The order of precedence for the node name is as follows (from highest to lowest)
  #
  # => ENV['CHEF_NODE_NAME']
  # => Looking for a file with the node name inside it
  # => Some future algorithm that will use the container API
  # => nil
  def self.node_name
    case

    # Highest order of precedence is an environment variable
    when ! ENV['CHEF_NODE_NAME'].nil?
      ENV['CHEF_NODE_NAME']

    # Next order, look for the .node_name file in /etc/chef
    when File.exist?('/etc/chef/.node_name')
      File.read('/etc/chef/.node_name').strip

    # Default is nil, which will cause Chef to take over
    else
      nil
    end
  end

end
