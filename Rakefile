require "bundler/gem_tasks"

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new do |t|
    t.pattern = 'spec/**/*_spec.rb'
  end
rescue LoadError
  desc "rspec is not installed, this task is disabled"
  task :spec do
    abort "rspec is not installed. `(sudo) gem install rspec` to run unit tests"
  end
end

desc 'build a dev docker image with the latest code'
task :build_dev do
  Rake::Task['build'].invoke
  system 'docker build -t chef-init-dev ./'
end

desc 'verify the dev docker image'
task :verify do
  pid = `docker run -d chef-init-dev chef-init --verify `
  system "docker logs -f #{pid}"
end

desc 'Build chef-init-dev image and run chef-init --verify'
task :build_and_verify do
  Rake::Task['build_dev'].invoke
  Rake::Task['verify'].invoke
end

desc 'Build chef-init-dev image and enter it'
task :build_and_enter do
  Rake::Task['build_dev'].invoke
  system `docker run -i -t chef-init-dev /bin/bash`
end

task :default => :spec
