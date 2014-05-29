require 'chef-init'

service "nginx"

container_service "nginx" do
  command "/usr/bin/nginx -c /etc/nginx/nginx.conf"
end
