require 'chef-init'

chef_server_url             'http://127.0.0.1:8889'
validation_client_name      'chef-validator'
validation_key              '/tmp/chef_data/secure/validation.pem'
client_key                  '/tmp/chef_data/secure/client.pem'
trusted_certs_dir           '/tmp/chef_data/secure/trusted_certs'
cookbook_path               ['/tmp/chef_data/cookbooks']


Ohai::Config[:disabled_plugins] = [
            :NetworkRoutes,
            :NetworkListeners,
            :inet,
            :inet6,
            :SystemProfile,
            :ip_scopes,
            :Java,
            :Groovy,
            :Erlang,
            :Mono,
            :Lua,
            :PHP,
            :Nodejs,
            :GCE,
            :Rackspace
]
