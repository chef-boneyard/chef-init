FROM chef/ubuntu-14.04:latest

## setup APT
RUN sed -i '1ideb mirror://mirrors.ubuntu.com/mirrors.txt trusty main restricted universe multiverse' /etc/apt/sources.list
RUN sed -i '1ideb mirror://mirrors.ubuntu.com/mirrors.txt trusty-updates main restricted universe multiverse' /etc/apt/sources.list
RUN sed -i '1ideb mirror://mirrors.ubuntu.com/mirrors.txt trusty-backports main restricted universe multiverse' /etc/apt/sources.list
RUN sed -i '1ideb mirror://mirrors.ubuntu.com/mirrors.txt trusty-security main restricted universe multiverse' /etc/apt/sources.list
RUN apt-get update
ENV DEBIAN_FRONTEND noninteractive

## install dependencies
RUN apt-get install -y git

## install Bats
RUN git clone https://github.com/sstephenson/bats.git
RUN bats/install.sh /usr/local

# Copy the chef-init gem over and install it!
COPY pkg/chef-init-0.4.0.dev.gem chef-init.gem
RUN /opt/chef/embedded/bin/gem install chef-init.gem --bindir '/opt/chef/bin' --no-ri --no-rdoc
