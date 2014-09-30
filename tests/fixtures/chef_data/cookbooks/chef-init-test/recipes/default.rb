template '/usr/local/bin/chef-init-test-manual' do
  source 'chef-init-test.erb'
  variables log_message: 'This process was started manually.'
  mode '0755'
  owner 'root'
  group 'root'
end

template '/usr/local/bin/chef-init-test-auto' do
  source 'chef-init-test.erb'
  variables log_message: 'This process was started automatically.'
  mode '0755'
  owner 'root'
  group 'root'
end

node.default['container_service']['chef-init-test-manual']['command'] = '/usr/local/bin/chef-init-test-manual'

service 'chef-init-test-manual' do
  action :start
end


node.default['container_service']['chef-init-test-auto']['command'] = '/usr/local/bin/chef-init-test-auto'

service 'chef-init-test-auto' do
  action [:start, :enable]
end
