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

require 'chef-init/helpers'

module ChefInit
  class Log
    class Reader
      include ChefInit::Helpers

      attr_accessor :thread
      attr_accessor :pipe
      attr_accessor :input, :output

      def initialize(pipe)
        @pipe = pipe
        self.output = $stdout
      end

      def run
        create_pipe
        @thread = Thread.new do
          read_from_pipe
        end
      end

      def start
        Thread.start(@thread)
      end

      def stop
        Thread.stop(@thread)
      end

      def kill
        Thread.kill(@thread)
        delete_pipe
      end

      def read_from_pipe
        self.input = open_pipe
        loop do
          log_line = input.gets.chomp
          output.puts log_line
        end
      end

      def open_pipe
        IO.open(@pipe, 'r+')
      end

      def create_pipe
        system_command("mkfifo #{@pipe}")
      end

      def delete_pipe
        system_command("rm #{@pipe}")
      end
    end
  end
end
