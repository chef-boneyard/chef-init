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

require 'chef-init/loggers/stdout'

module ChefInit
  #
  # This is the base class for logging implementations called by ChefInit::Logger.
  #
  class Loggers

    def initialize
      # Do nothing
    end

    #
    # Write the log line to the destination
    #
    # @param [String] line
    #   The line of text to write to the destination
    #
    def write(line)
      raise ChefInit::Exceptions::LoggerNotImplemented, "#{self.to_s} did not " \
        'implement a method to write to the destination.'
    end
  end
end
