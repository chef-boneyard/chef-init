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

require 'chef/provider/service'
require 'chef/mixin/shell_out'
require 'chef/mixin/language'

class Chef
  class Exceptions
    class Supervisor < RuntimeError; end
  end
end

class Chef
  class Provider
    class Supervisor < Chef::Provider::Service
      include Chef::Mixin::ShellOut

      def initialize(name, run_context=nil)
        super
      end

      ##
      # Omnibus Helper Methods
      #
      def omnibus_root
        '/opt/chef'
      end

      def omnibus_embedded_bin_dir
        ::File.join(omnibus_root, "embedded", "bin")
      end
    end
  end
end
