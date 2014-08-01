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


require 'mixlib/shellout'
require 'chef-init/log'
require 'chef-init/exceptions'

module ChefInit
  module Helpers
    include ChefInit::Exceptions

    #
    # Runs given commands using mixlib-shellout
    #
    def system_command(*command_args)
      cmd = Mixlib::ShellOut.new(*command_args)
      cmd.run_command
      cmd
    end

    def err(message)
      stderr.print("#{message}\n")
    end

    def msg(message)
      stdout.print("#{message}\n")
    end

    def stdout
      $stdout
    end

    def stderr
      $stderr
    end

    def exit(n)
      Kernel.exit(n)
    end

    #
    # Locates the omnibus directories
    #

    def omnibus_root
      "/opt/chef"
    end

    def omnibus_bin_dir
      "/opt/chef/bin"
    end

    def omnibus_embedded_bin_dir
      "/opt/chef/embedded/bin"
    end

    def data_path
      File.expand_path(File.dirname(__FILE__) + "../../../data")
    end

    def path
      "#{omnibus_root}/bin:#{omnibus_root}/embedded/bin:/usr/local/bin:/usr/local/sbin:/bin:/sbin:/usr/bin:/usr/sbin"
    end
  end
end
