# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chef-init/version'

Gem::Specification.new do |s|
  s.name          = 'chef-init'
  s.version       = ChefInit::VERSION
  s.authors       = ['Tom Duffield']
  s.email         = ['tom@getchef.com']
  s.summary       = %q{The process supervisor designed to work with chef-container.}
  s.description   = s.summary
  s.homepage      = 'http://getchef.com'
  s.license       = 'Apache 2.0'

  s.files = %w(Rakefile README.md CONTRIBUTING.md) + Dir.glob("{bin,lib,spec}/**/*", File::FNM_DOTMATCH).reject do |f|
    File.directory?(f)
  end
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_dependency 'chef', '= 12.0.0.alpha.2'

  s.add_development_dependency 'rake', '~> 10.3.0'
  %w( rspec rspec-core rspec-expectations rspec-mocks).each do |rspec|
    s.add_development_dependency rspec, '~> 3.0.0'
  end
end
