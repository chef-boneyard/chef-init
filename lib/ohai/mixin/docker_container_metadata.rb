
require 'net/http'
require 'socket'

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end

module Ohai
  module Mixin

    ##
    # This code parses the Docker Remote API to provide details
    # of the running Docker container. 
    #
    # At this time, it only supports the unix socket scheme.
    module DockerContainerMetadata

      DOCKER_METADATA_ADDR = "unix:///var/run/docker.sock" unless defined?(DOCKER_METADATA_ADDR)

      ##
      # Test connection to Docker Remote API socket
      #
      def can_metadata_connect?(addr=DOCKER_METADATA_ADDR, port=nil, timeout=2)
        t = Socket.new(Socket::Constants::AF_INET, Socket::Constants::SOCK_STREAM, 0)
        saddr = Socket.pack_sockaddr_un(DOCKER_METADATA_ADDR)
        connected = false

        begin
          t.connect_nonblock(saddr)
        rescue Errno::EINPROGRESS
          r,w,e = IO.select(nil,[t],nil,timeout)
          if !w.nil?
            connected = true
          else
            begin
              t.connect_nonblock(saddr)
            rescue Errno::EISCONN
              t.close
              connected = true
            end
          end
        rescue SystemCallError
        end
        Ohai::Log.debug("can_metadata_connect? == #{connected}")
        connected
      end

      ##
      # Is there a container in the API that matches the current node?
      #
      def can_find_container?
        response = request("/containers/#{container_id}/json")
        response.code == '200'
      end

      ##
      # Determine the name of the container by referencing the hostname
      #
      def container_id
        shell_out("hostname").stdout.strip
      end

      def fetch_metadata
        response = request("/containers/#{container_id}/json")
        return nil unless response.code == "200"

        data = StringIO.new(response.body)
        parser = Yajl::Parser.new
        parser.parse(data)
      end

      ##
      # Submit API request
      #
      def request(uri)
        socket = Net::BufferedIO.new(UNIXSocket.new(DOCKER_METADATA_ADDR))
        request = Net::HTTP::Get.new(uri)
        request.exec(socket, "1.1", uri)

        begin
          response = Net::HTTPResponse.read_new(socket)
        end while response.kind_of?(Net::HTTPContinue)
        response.reading_body(socket, request.response_body_permitted?) {}
        
        return {
          :body => response.body,
          :code => response.code
        }
      end
    end 
  end
end
