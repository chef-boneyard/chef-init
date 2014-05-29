
Ohai.plugin(:DockerContainer) do
  include Ohai::Mixin::DockerContainerMetadata

  provides "docker_container"

  def looks_like_docker?
    hint?('docker_container') || can_metadata_connect? && can_find_container?
  end

  ##
  # The format of the data is collection is the inspect API
  # http://docs.docker.io/reference/api/docker_remote_api_v1.11/#inspect-a-container
  #
  collect_data do
    if looks_like_docker?
      Ohai::Log.debug("looks_like_docker? == true")
      docker_container Mash.new
      fetch_metadata.each { |k,v| docker_container[k] = v }
    else
      Ohai::Log.debug("looks_like_docker? == false")
      false
    end
  end
end

