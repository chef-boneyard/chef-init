require 'spec_helper'
require 'chef/resource/runit_supervisor'

describe Chef::Resource::RunitSupervisor do

  before(:each) do
    @resource = Chef::Resource::RunitSupervisor.new("foo")
  end

  it 'should return a Chef::Resource::RunitSupervisor' do
    expect(@resource).to be_a_kind_of(Chef::Resource::RunitSupervisor)
  end

  it 'should set the service_name to :runit_supervisor' do
    expect(@resource.resource_name).to eql(:runit_supervisor)
  end

  it 'should set the provider to Chef::Provider::Supervisor::Runit' do
    expect(@resource.provider).to eql(Chef::Provider::Supervisor::Runit)
  end

  it 'should set the sv_bin to /opt/chef/embedded/bin/sv' do
    expect(@resource.sv_bin).to eql('/opt/chef/embedded/bin/sv')
  end

  it 'should set the service_dir to /opt/chef/service' do
    expect(@resource.service_dir).to eql('/opt/chef/service')
  end
end
