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

require 'sys/proctable'
require 'chef-init/helpers'

module ChefInit
  class Process
    include Sys
    include ChefInit::Helpers

    @@terminated_child_processes = {}
    @@monitor_child_processes = []

    def self.find_by_name(name)
      Proctable.ps do |proc|
        if proc.cmdline =~ process_name
          return proc.pid
        end
      end
      raise NotFound
    end

    def self.running?(pid)
      if id.is_a? Integer
        Proctable.ps(id).nil?
      elsif id.is_a? String
        Proctable.ps(get_pid(id)).nil?
      else
        false
      end
    end

    # Waits for the child process with the given PID, while at the same time
    # reaping any other child processes that have exited (e.g. adopted child
    # processes that have terminated).
    # (code from https://github.com/phusion/baseimage-docker translated from python)
    def self.wait(pid)
      if @@terminated_child_processes.include?(pid)
        # A previous call to waitpid_reap_other_children(),
        # with an argument not equal to the current argument,
        # already waited for this process. Return the status
        # that was obtained back then.
        return @@terminated_child_processes.delete(pid)
      end
      done = false
      status = nil
      until done
        begin
          this_pid, status = ::Process.wait2(-1, 0)
          if this_pid == pid
            done = true
          elsif @@monitor_child_processes.include?(pid)
            @@terminated_child_processes[this_pid] = status
          end
        rescue Errno::ECHILD, Errno::ESRCH
          return
        end
      end
      status
    end

    def self.kill(pid)
      ::Process.kill('HUP', pid)
      sleep 3
      ::Process.kill('TERM', pid)
      sleep 3
      ::Process.kill('KILL', pid)
      self.class.wait(pid)
    end

    attr_reader :pid
    attr_reader :command
    attr_reader :exitstatus

    def initialize(command, path=Helpers.path)
      @command = command
      @pid = nil
      @path = path
    end

    def launch
      @pid = fork do
        exec({"PATH" => @path}, @command)
      end
      @@monitor_child_processes << @pid
      @pid
    end

    def kill
      self.class.kill(@pid)
    end

    def wait
      @exitstatus = self.class.wait(@pid)
    end

    def running?
      self.class.running?(@pid)
    end

    class NotFound < RuntimeError
      def initialize
        super("The process you specified could not be found.")
      end
    end

  end
end
