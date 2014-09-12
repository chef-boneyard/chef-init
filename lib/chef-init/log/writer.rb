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
require 'mixlib/cli'
require 'chef-init/helpers'

module ChefInit
  class Log
    class Writer
      include Mixlib::CLI
      include ChefInit::Helpers

      attr_accessor :input, :output

      option :service_name,
        short:        '-s SERVICE_NAME',
        long:         '--service-name SERVICE_NAME',
        description:  'The name of the service being logged.',
        required:     true

      def initialize(argv)
        @argv = argv
        self.input = $stdin
        if File.exist?(log_pipe)
          self.output = IO.open(log_pipe, 'w+')
        else
          err "The logging pipe for chef-init does not exist. This indicates an "\
              "error with chef-init. Please investigate."
          exit false
        end
        super()
      end

      # The main method that runs when the object is called.
      def run
        parse_options(@argv)

        # Read the incoming log lines from STDOUT
        Thread.new do
          loop do
            log_line = input.gets.chomp
            send_to_pid1(log_line)
          end
        end
      end

      # Returns the name of the service that is sending log data to this logger.
      #
      # @return [String] the name of the service
      def service_name
        config[:service_name]
      end

      # Sends a line of text to a special pipe that chef-init knows to listen on.
      #
      # @param [String] a log line
      def send_to_pid1(line)
        output.puts "[#{service_name}] #{line}"
        output.flush
      end
    end
  end
end
