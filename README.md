# chef-init
chef-init is a RubyGem that is distributed with [chef-container] and intended to be used as PID1 inside Linux Containers. 
[![Gem Version](https://badge.fury.io/rb/chef-init.png)](http://badge.fury.io/rb/chef-init) [![Build Status](https://travis-ci.org/opscode/chef-init.svg?branch=master)](https://travis-ci.org/opscode/chef-init)

It’s primary purpose is to provide an interface with which to safely launch a chef-client run and a process supervisor to manage the services that your Chef recipes create. 

It’s secondary purpose is to provide useful Chef Resources and Recipe DSLs that you can use to interface more cleanly with the process supervisor.

## Installation
This RubyGem is already bundled with [chef-container] and should not be install separately at this time.

## Usage
Check out the documentation [here](http://docs.opscode.com/containers.html)

## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md)

## License
Full License: [here](LICENSE)

ChefInit - a PID1 for your Docker Containers

Author:: Tom Duffield (<tom@getchef.com>)
Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

