FROM tduffield/chef-init-base

# Copy the chef-init gem over and install it!
COPY pkg/chef-init-1.0.0.dev.gem chef-init.gem
RUN /opt/chef/embedded/bin/gem install chef-init.gem --bindir '/opt/chef/bin' --no-ri --no-rdoc
