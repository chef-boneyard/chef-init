
require 'chef/provider/service'
require 'chef/mixin/shell_out'
require 'chef/mixin/language'

class Chef
  class Exceptions
    class Supervisor < RuntimeError; end
  end
end

class Chef
  class Provider
    class Supervisor < Chef::Provider::Service
      include Chef::Mixin::ShellOut

      def initialize(name, run_context=nil)
        super
      end

      ##
      # Omnibus Helper Methods
      #
      def omnibus_root
        '/opt/chef'
      end

      def omnibus_embedded_bin_dir
        ::File.join(omnibus_root, "embedded", "bin")
      end
    end
  end
end
