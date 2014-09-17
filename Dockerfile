FROM chef-container-dev
COPY pkg/chef-init-0.4.0.dev.gem chef-init.gem
RUN /opt/chef/embedded/bin/gem install chef-init.gem --bindir '/opt/chef/bin' --no-ri --no-rdoc
