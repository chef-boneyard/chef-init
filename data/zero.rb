require 'chef-init'

cookbook_path   ["#{File.expand_path(File.dirname(__FILE__))}/cookbooks"]
ssl_verify_mode   :verify_peer
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
