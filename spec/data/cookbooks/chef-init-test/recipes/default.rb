cookbook_file '/usr/local/bin/chef-init-test' do
  mode '0755'
  owner 'root'
  group 'root'
end

service 'chef-init-test' do
  action :start
end
