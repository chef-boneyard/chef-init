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

require 'chef/resource/link'
require 'chef/provider/link'
require 'chef/resource/file'
require 'chef/provider/file'
require 'chef/resource/directory'
require 'chef/provider/directory'
require 'chef/provider/container_service'
require 'chef-init/helpers'

class Chef
  class Provider
    class ContainerService
      class Runit < Chef::Provider::ContainerService
        include ChefInit::Helpers

        attr_reader :command
        attr_reader :log_type # stdout, file

        def initialize(name, run_context=nil)
          super
          @new_resource.supports[:status] = true
          @staging_dir = nil
          @down_file = nil
          @run_script = nil
          @log_dir = nil
          @log_main_dir = nil
          @log_run_script = nil
          @service_dir_link = nil

          options = node['container_service'][new_resource.service_name]
          @command = options['command']
          @log_type = options['log_type'].nil? ? :stdout : options['log_type'].to_sym
        end

        def load_current_resource
          @current_resource = Chef::Resource::Service.new(new_resource.name, run_context)
          @current_resource.service_name(new_resource.service_name)

          setup

          # Check the current status of the runit service
          @current_resource.running(running?)
          @current_resource.enabled(enabled?)
          @current_resource
        end

        #
        # The +setup+ action will create the files and folders necessary to
        # manage a runit service.
        #
        # This action does not need to be called within the service resource.
        # It is called automatically when the +node[:container_service]+
        # mattribute is detected.
        #
        def setup
          Chef::Log.debug("Creating service staging directory for #{new_resource.service_name}")
          staging_dir.run_action(:create)

          Chef::Log.debug("Creating service directory")
          service_dir.run_action(:create)

          Chef::Log.debug("Creating down file for #{new_resource.service_name}")
          down_file.run_action(:create)

          Chef::Log.debug("Creating run script for #{new_resource.service_name}")
          run_script.run_action(:create)

          if @log_type.eql?(:file)
            Chef::Log.debug("Creating /var/log directory for #{new_resource.service_name}")
            log_dir.run_action(:create)
          end

          Chef::Log.debug("Creating log dir for #{new_resource.service_name}")
          log_main_dir.run_action(:create)

          Chef::Log.debug("Creating log run script for #{new_resource.service_name}")
          log_run_script.run_action(:create)

          Chef::Log.debug("Linking staging directory to service directory for #{new_resource.service_name}")
          service_dir_link.run_action(:create)
        end


        #
        # Enable the runit service by removing the +down+ file.
        #
        def enable_service
          down_file.run_action(:delete)
        end

        #
        # Disable the runit service by creating the +down+ file and running
        # the +down+ command.
        #
        def disable_service
          down_file.run_action(:create)
          shell_out("#{sv_bin} down #{service_dir_name}")
          Chef::Log.debug("#{new_resource} down")
        end

        #
        # Wait for runit to acknowledge that it recognizes the service and
        # then start it.
        #
        def start_service
          wait_for_service_enable
          shell_out!("#{sv_bin} start #{service_dir_name}")
        end

        #
        # Stop the runit service
        #
        def stop_service
          shell_out!("#{sv_bin} stop #{service_dir_name}")
        end

        #
        # Restart the runit service
        #
        def restart_service
          shell_out!("#{sv_bin} restart #{service_dir_name}")
        end

        #
        # Reload the runit service
        #
        def reload_service
          shell_out!("#{sv_bin} force-reload #{service_dir_name}")
        end

        #
        # Returns whether the runit process is currently running by parsing the
        # output of the runit status command
        #
        # @return [Boolean]
        #
        def running?
          cmd = shell_out("#{sv_bin} status #{service_dir_name}")
          (cmd.stdout.match(/^run:/) && cmd.exitstatus == 0) ? true : false
        end

        #
        # Returns whether the service is enabled by detecting whether or not
        # the down files exists. If the file exists, then the service is disabled.
        # If the file does not exist, then the service is enabled.
        #
        # @return [Boolean]
        #
        def enabled?
          !::File.exists?(::File.join(service_dir_name, 'down'))
        end

        #
        # Wait until the necessary pipes are created that signify that the
        # service is now being managed by runit.
        #
        def wait_for_service_enable
          Chef::Log.debug("waiting until named pipe #{service_dir_name}/supervise/ok exists.")
          until ::FileTest.pipe?("#{service_dir_name}/supervise/ok")
            sleep 1
            Chef::Log.debug('.')
          end

          Chef::Log.debug("waiting until named pipe #{service_dir_name}/log/supervise/ok exists.")
          until ::FileTest.pipe?("#{service_dir_name}/log/supervise/ok")
            sleep 1
            Chef::Log.debug('.')
          end
        end

        #
        # Returns the path to the directory where the service lives. This path
        # is actually a symlink to the path in the +staging_dir_name+ method.
        #
        # @return [String]
        #
        def service_dir_name
          ::File.join(omnibus_root, 'service', new_resource.service_name)
        end

        #
        # Returns the path to the directory where the service configuration is.
        #
        # @return [String]
        def staging_dir_name
          ::File.join(omnibus_root, 'sv', new_resource.service_name)
        end

        #
        # Returns the path to the +sv+ binary that is used to send commands to
        # the runit process.
        #
        # @return [String]
        #
        def sv_bin
          ::File.join(omnibus_embedded_bin_dir, 'sv')
        end

        #
        # Returns the content that will go into the run file runit uses to launch
        # the service.
        #
        # @return [String]
        #
        def run_script_content
          content = "#!/bin/sh\n"
          content += "exec 2>&1\n"
          content += "exec #{@command} 2>&1"
        end

        #
        # Returns the content that will go into the run file runit uses to collect
        # the log output from the service.
        #
        # @return [String]
        #
        def log_run_script_content
          content = "#!/bin/sh\n"
          case @log_type
          when :stdout
            content += "exec chef-init-logger --service-name #{new_resource.service_name} --log-destination stdout"
          when :file
            content += "exec svlogd -tt /var/log/#{new_resource.service_name}"
          end
          content
        end

        #
        # Returns the +directory+ resource that will be used to create the
        # +/opt/chef/sv+ directory where the service configurations will live.
        #
        # When a service is managed by runit, a directory for that service will
        # be created here.
        #
        # @return [Chef::Resource::Directory]
        #
        def staging_dir
          return @staging_dir unless @staging_dir.nil?
          @staging_dir = Chef::Resource::Directory.new(staging_dir_name, run_context)
          @staging_dir.recursive(true)
          @staging_dir.mode(00755)
          @staging_dir
        end

        #
        # Returns the +directory+ resource that will be used to create the
        # +/opt/chef/service+ directory where active services will live.
        #
        # When a service has been activated (meaning runit will be aware of it),
        # a symlink will be created inside this directory to a corresponding
        # directory in the staging directory.
        #
        # @return [Chef::Resource::Directory]
        #
        def service_dir
          return @service_dir unless @service_dir.nil?
          @service_dir = Chef::Resource::Directory.new(::File.join(omnibus_root, 'service'), run_context)
          @service_dir.recursive(true)
          @service_dir.mode(00755)
          @service_dir
        end

        #
        # Returns the +file+ resource that will be used to create the run script
        # that runit will use to launch the process.
        #
        # @return [Chef::Resource::File]
        #
        def run_script
          return @run_script unless @run_script.nil?
          @run_script = Chef::Resource::File.new(::File.join(staging_dir_name, 'run'), run_context)
          @run_script.content(run_script_content)
          @run_script.mode(00755)
          @run_script
        end

        #
        # Returns the +directory+ resource that will be used to create log
        # directory where the log output of the service will be placed and
        # managed with svlogd. This method is only called if the +log_type+
        # is set to +file+.
        #
        # @return [Chef::Resource::Directory]
        #
        def log_dir
          return @log_dir unless @log_dir.nil?
          @log_dir = Chef::Resource::Directory.new("/var/log/#{new_resource.service_name}", run_context)
          @log_dir.recursive(true)
          @log_dir.mode(00755)
          @log_dir
        end

        #
        # Returns the +directory+ resource that will be used to create the log
        # directory in the service configuration path where the configuration
        # for the log output will be held.
        #
        # @return [Chef::Resource::Directory]
        #
        def log_main_dir
          return @log_main_dir unless @log_main_dir.nil?
          @log_main_dir = Chef::Resource::Directory.new(::File.join(staging_dir_name, 'log'), run_context)
          @log_main_dir.recursive(true)
          @log_main_dir.mode(00755)
          @log_main_dir
        end

        #
        # Returns the +file+ resource that will be used to create the run script
        # that runit will use to launch the logging process that will collect
        # the log output of the runit service.
        #
        # @return [Chef::Resource::File]
        #
        def log_run_script
          return @log_run_script unless @log_run_script.nil?
          @log_run_script = Chef::Resource::File.new(::File.join(staging_dir_name, 'log', 'run'), run_context)
          @log_run_script.content(log_run_script_content)
          @log_run_script.mode(00755)
          @log_run_script
        end

        #
        # Returns the +link+ resource that will be used to create the symlink
        # between the service configuration folder in +/opt/chef/sv+ and the
        # active service folder +/opt/chef/service+.
        #
        # @return [Chef::Resource::Link]
        #
        def service_dir_link
          return @service_dir_link unless @service_dir_link.nil?
          @service_dir_link = Chef::Resource::Link.new(::File.join(service_dir_name), run_context)
          @service_dir_link.to(staging_dir_name)
          @service_dir_link
        end

        #
        # Returns the +file+ resource that will be used to manage the +down+
        # file that will indicate whether the runit service is enabled at boot.
        #
        # @return [Chef::Resource::File]
        #
        def down_file
          return @down_file unless @down_file.nil?
          @down_file = Chef::Resource::File.new(::File.join(staging_dir_name, 'down'), run_context)
          @down_file.backup(false)
          @down_file
        end
      end
    end
  end
end
