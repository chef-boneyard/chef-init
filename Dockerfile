FROM chef/ubuntu-12.04:latest
ADD pkg/chef-init-0.3.0.dev.gem chef-init.gem
RUN /opt/chef/embedded/bin/gem install chef-init.gem --bindir /opt/chef/bin --no-ri --no-rdoc
