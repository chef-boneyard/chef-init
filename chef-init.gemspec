# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef-init/version'

Gem::Specification.new do |s|
  s.name          = "chef-init"
  s.version       = ChefInit::VERSION
  s.authors       = ["Tom Duffield"]
  s.email         = ["tom@getchef.com"]
  s.summary       = %q{The process supervisor designed to work with chef-container.}
  s.description   = s.summary
  s.homepage      = "http://getchef.com"
  s.license       = "Apache 2.0"

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency "mixlib-cli", "~> 1.5"
  s.add_dependency "mixlib-shellout", "~> 1.4"
  s.add_dependency "mixlib-log", "~> 1.1"
  s.add_dependency "chef", "~> 11.12"

  s.add_development_dependency "rspec", "~> 2.14.0"
  s.add_development_dependency "rspec-core", "~> 2.14.0"
  s.add_development_dependency "rspec-expectations", "~> 2.14.0"
  s.add_development_dependency "rspec-mocks", "~> 2.14.0"
  s.add_development_dependency "simplecov", "~> 0.7.1"
end
