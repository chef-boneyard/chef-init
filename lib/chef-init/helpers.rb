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
    # See the Mixlib::Shellout documentation for parameters.
    #
    def system_command(*command_args)
      cmd = Mixlib::ShellOut.new(*command_args)
      cmd.run_command
      cmd
    end

    #
    # Prints the given message to STDERR
    #
    # @param [String] message
    #   The message to print to STDERR
    #
    def err(message)
      stderr.print("#{message}\n")
    end

    #
    # Prints the given message to STDOUT
    #
    # @param [String] message
    #   The message to print to STDOUT
    #
    def msg(message)
      stdout.print("#{message}\n")
    end

    #
    # A class-specified reference to STDOUT. This is done
    # primarily to make STDOUT material easy to capture for
    # testing.
    #
    def stdout
      $stdout
    end

    #
    # A class-specified reference to STDERR. This is done
    # primarily to make STDERR material easy to capture for
    # testing.
    #
    def stderr
      $stderr
    end

    #
    # A wrapper around the Kernel exit method. This is done
    # primarily to make exit commands easier to capture for
    # testing.
    #
    def exit(n)
      Kernel.exit(n)
    end

    #
    # Returns the path to the root path where the omnibus package expanded to.
    # In the future, this value may be variable (if we ever support windows)
    # but for right now it is static.
    #
    # @return [String]
    #
    def omnibus_root
      '/opt/chef'
    end

    #
    # Returns the path to the directory where the primary binaries are stored.
    # These are the binaries that are designed to be accessible to the end user.
    #
    # @return [String]
    #
    def omnibus_bin_dir
      '/opt/chef/bin'
    end

    #
    # Returns the path to the directory where the embedded binaries are stored.
    # These are the binaries that primary binaries will use but are not intended
    # to be used by the end user.
    #
    # @return [String]
    #
    def omnibus_embedded_bin_dir
      '/opt/chef/embedded/bin'
    end

    #
    # Returns a modified path string that includes the primary and embedded binary
    # paths.
    #
    # @return [String]
    #
    def path
      "#{omnibus_bin_dir}:#{omnibus_embedded_bin_dir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    end
  end
end
