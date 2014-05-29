FROM chef/ubuntu_12.04:latest
ADD chef-init-0.0.1.gem /tmp/chef-init-0.0.1.gem
RUN /opt/chef/embedded/bin/gem install /tmp/chef-init-0.0.1.gem
ENTRYPOINT ["/opt/chef/embedded/bin/"]
