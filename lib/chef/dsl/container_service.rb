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
require 'chef/resource/runit_supervisor'
require 'chef/provider/service/supervisor/runit'

class Chef
  class Exceptions
    class Supervisor < RuntimeError; end
  end
end

class Chef
  class Recipe
    
    # Hijacks an existing service resource and changes the backend provider.
    # It also creates the files and folders necessary to manage the runit service.
    #
    # For example:
    #   # cookbook 'nginx' has several `service[nginx]` declarations. This will 
    #
    #   container_service 'nginx' do
    #     command '/usr/sbin/nginx -c /etc/nginx/nginx.conf'
    #   end
    #
    # ==== Parameters
    # name<String>:: Name of the service to hijack
    # block<Proc>:: Block with the command to use to create supervisor service
    #
    def container_service(name, &block)
      begin
        # Find the corresponding `service` resource and override the provider
        service_resource = resources("service[#{name}]")

        # Setup and configure the supervisor
        supervisor = Chef::Resource::RunitSupervisor.new(name, run_context)
        supervisor.instance_exec(&block) if block
        supervisor.run_action(:enable)

        # override `service` provider with Chef::Provider::Service::RunitSupervisor
        service_resource.provider = Chef::Provider::Service::Supervisor::Runit
      rescue Chef::Exceptions::ResourceNotFound => e
        Chef::Log.info "Resource service[#{name}] not found."
        raise e
      end
    end

  end
end
