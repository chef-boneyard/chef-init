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
  # This class is the interaction point with the provisioner. In this case, the
  # provisioner is chef-client.
  #
  class Provisioner
    include ChefInit::Helpers

    attr_accessor :provisioner

    def initialize
      @provisioner = nil
    end

    #
    # Run the provisioner
    #
    # @param [Array] options
    #   An array of options to pass to chef-client
    #
    def run(options=[])
      @provisioner = ::ChildProcess.build('chef-client', *options)
      @provisioner.io.inherit!
      @provisioner.leader = true
      @provisioner.environment['PATH'] = path
      @provisioner.start
      @provisioner.wait
    end

    #
    # Returns the exit code for chef-client
    #
    # @return [Fixnum]
    #
    def exit_code
      @provisioner.exit_code
    end

  end
end
