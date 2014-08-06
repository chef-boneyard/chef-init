FROM chef/ubuntu-12.04:latest
COPY pkg/chef-init-0.3.0.gem chef-init.gem
RUN /opt/chef/embedded/bin/gem install chef-init.gem --bindir '/opt/chef/bin' --no-ri --no-rdoc
