require 'chef-init'

chef_server_url     'http://127.0.0.1:8889'
node_name           ChefInit.node_name
client_key          "./empty_client.pem"


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
