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

require 'childprocess'
require 'chef-init/helpers'

module ChefInit
  #
  # This class is the interaction point with the process supervisor that chef-init
  # delegates management of child processes to.
  #
  class Supervisor
    include ChefInit::Helpers

    attr_accessor :supervisor

    def initialize()
      @supervisor = ::ChildProcess.build(
        "#{omnibus_embedded_bin_dir}/runsvdir",
        "-P", "#{omnibus_root}/service"
      )
    end

    #
    # Launches the supervisor process.
    #
    def launch()
      @supervisor.io.inherit!
      @supervisor.leader = true
      @supervisor.environment['PATH'] = path
      @supervisor.start
    end

    #
    # Waits for the supervisor to exit
    #
    def wait()
      @supervisor.wait
    rescue Errno::ECHILD => e
      # The process was killed, so we're happy
    end

    #
    # Shutsdown the supervisor and all the child processes
    #
    def shutdown()
      ChefInit::Log.debug("Waiting for services to stop...")

      ChefInit::Log.debug("Exit all the services")
      system_command("#{omnibus_embedded_bin_dir}/sv stop #{omnibus_root}/service/*")
      system_command("#{omnibus_embedded_bin_dir}/sv exit #{omnibus_root}/service/*")

      ChefInit::Log.debug("Send HUP to the Supervisor")
      ::Process.kill('HUP', @supervisor.pid) # Gently kill the process

      begin
        @supervisor.poll_for_exit(10)
      rescue ChildProcess::TimeoutError
        @supervisor.stop # tries increasingly harsher methods to kill the supervisor.
      end

      ChefInit::Log.debug("Shutdown complete...")
    end
  end
end
