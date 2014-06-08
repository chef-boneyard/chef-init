require 'spec_helper'
require 'chef/resource/supervisor'

describe Chef::Resource::Supervisor do

  before(:each) do
    @resource = Chef::Resource::Supervisor.new("foo")
  end

  it 'should return a Chef::Resource::Supervisor' do
    expect(@resource).to be_a_kind_of(Chef::Resource::Supervisor)
  end

  it 'should be a sub-class of Chef::Resource::Service' do
    expect(@resource).to be_a_kind_of(Chef::Resource::Service)
  end

  it 'should have a resource name of :supervisor' do
    expect(@resource.resource_name).to eql(:supervisor)
  end

  it 'should have a provider of Chef::Provider::Supervisor' do
    expect(@resource.provider).to eql(Chef::Provider::Supervisor::Runit)
  end

  it 'should have a binary of opt/chef/embedded/bin/sv' do
    expect(@resource.binary).to eql('/opt/chef/embedded/bin/sv')
  end

  it 'should require a command parameter' do
  end
end
