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
require 'logger'
require 'chef-init/helpers'
require 'chef/mixin/convert_to_class_name'

module ChefInit
  #
  # The Logger class is used to read and write log lines from services being
  # managed by chef-init. It will accept data via STDIN and then output to a
  # destination specified in the parameters. The parameter must match a prewritten
  # logging implementation found in chef-init/loggers. Currently the only
  # supported logging implementation is writing to STDOUT.
  #
  class Logger
    include Mixlib::CLI
    include ChefInit::Helpers
    include Chef::Mixin::ConvertToClassName

    attr_accessor :source
    attr_accessor :destination

    option :service_name,
      short:        '-s SERVICE_NAME',
      long:         '--service-name SERVICE_NAME',
      description:  'The name of the service being logged.',
      required:     true

    option :log_destination,
      short:        '-d LOG_DESTINATION',
      long:         '--log-destination LOG_DESTINATION',
      description:  'The destination for the log output.',
      default:      'stdout'

    def initialize(argv)
      @argv = argv
      super()
    end

    #
    # The main program will evaluate the options and then create a thread that
    # reads from the input and writes a log line with the service name prepended
    # to the destination.
    #
    def run
      parse_options(@argv)
      logger = ::Logger.new(output)
      logger.progname = service_name
      logger.level = ::Logger::INFO
      logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{progname}] #{msg}\n"
      end

      input.each do |line|
        logger.info line.chomp!
      end
    end

    #
    # Returns the name of the service that is sending log data to the logger.
    #
    # @return [String]
    #
    def service_name
      config[:service_name]
    end

    #
    # Returns the file descriptor for the input where the log lines come from.
    # When using with Runit, this will always be STDIN.
    #
    # @return [Constant]
    #
    def input
      $stdin
    end

    #
    # Returns where the Logger should log to.
    #
    def output
      case config[:log_destination]
      when 'stdout'
        stdout
      end
    end
  end
end
