#
# Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'chef'
require 'chef/recipe'
require 'ohai'

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
$:.unshift(File.expand_path("../lib", __FILE__))
$:.unshift(File.dirname(__FILE__))

# Ohai Rspec
PLUGIN_PATH = File.expand_path("../../lib/ohai/plugins", __FILE__)
SPEC_PLUGIN_PATH = File.expand_path("../data/plugins", __FILE__)
def get_plugin(plugin, ohai = Ohai::System.new, path = PLUGIN_PATH)
  loader = Ohai::Loader.new(ohai)
  loader.load_plugin(File.join(path, "#{plugin}.rb"))
end
