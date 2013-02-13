#
# Cookbook Name:: nginx-passenger
# Recipe:: default
#
# Copyright 2012, ScribTeX Ltd.
#
# All rights reserved - Do Not Redistribute
#

##########################
# Ruby Enterpise Edition #
##########################

# required packages for install
package "libreadline-dev"
package "build-essential"
package "libssl-dev"

node.default[:ruby_enterprise][:version] = "1.8.7-2012.02"
node.default[:ruby_enterprise][:src_dir] = "#{Chef::Config[:file_cache_path]}/ruby-enterprise-#{node[:ruby_enterprise][:version]}"
node.default[:ruby_enterprise][:install_dir] = "/opt/ruby-enterprise-#{node[:ruby_enterprise][:version]}"
node.default[:ruby_enterprise][:gem_binary] = "#{node[:ruby_enterprise][:install_dir]}/bin/gem"

remote_file "#{Chef::Config[:file_cache_path]}/ruby-enterprise-#{node[:ruby_enterprise][:version]}.tar.gz" do
  source "http://rubyenterpriseedition.googlecode.com/files/ruby-enterprise-#{node[:ruby_enterprise][:version]}.tar.gz"
  action :create_if_missing
end

ruby_enterprise_src_dir = bash "extract_ruby_enterprise_source" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxf ruby-enterprise-#{node[:ruby_enterprise][:version]}.tar.gz
  EOH
  creates node[:ruby_enterprise][:src_dir]
end

# Note that you may need to add in the 'volatile' key word to one of the source
# files before it will compile:
# http://code.google.com/p/rubyenterpriseedition/issues/detail?id=74
file "#{node[:ruby_enterprise][:src_dir]}/volatile_patch.diff" do
	content <<-EOS
--- source/distro/google-perftools-1.7/src/tcmalloc.cc 2012-02-19 14:09:11.000000000 +0000
+++ source/distro/google-perftools-1.7/src/tcmalloc.cc.new 2013-02-12 11:57:47.000000000 +0000
@@ -1669,5 +1669,5 @@
   MallocHook::InvokeNewHook(result, size);
   return result;
 }
-void *(*__memalign_hook)(size_t, size_t, const void *) = MemalignOverride;
+void *(* volatile __memalign_hook)(size_t, size_t, const void *) = MemalignOverride;
 #endif  // #ifndef TCMALLOC_FOR_DEBUGALLOCATION
EOS
end
execute "Patch ruby enterprise installer" do
  command "patch -p0 --forward < volatile_patch.diff"
  cwd     node[:ruby_enterprise][:src_dir]
  returns [0, 1]
end

execute "install_ruby_enterprise" do
  command [
    node[:ruby_enterprise][:src_dir] + "/installer",
    "-a", node[:ruby_enterprise][:install_dir]
  ].join(" ")

  creates node[:ruby_enterprise][:install_dir]
end

###################################################
# Install passenger using ruby enterprise edition #
###################################################

package "build-essential"
package "ruby1.8-dev"

###########################
# Fetch the nginx sources #
###########################

node.default[:nginx][:version] = "1.2.6"
node.default[:nginx][:src_dir] = "#{Chef::Config[:file_cache_path]}/nginx-#{node[:nginx][:version]}"
node.default[:nginx][:installer]      = "#{node[:ruby_enterprise][:install_dir]}/bin/passenger-install-nginx-module"
node.default[:nginx][:install_path]   = "/opt/nginx-#{node[:nginx][:version]}"
node.default[:nginx][:binary_path]    = node[:nginx][:install_path] + "/sbin/nginx"
node.default[:nginx][:error_log_path] = "/var/log/nginx/error.log"
node.default[:nginx][:http_log_path]  = "/var/log/nginx/access.log"
node.default[:nginx][:pid_path]       = "/var/run/nginx.pid"
node.default[:nginx][:conf_path]      = node[:nginx][:install_path] + "/conf/nginx.conf"
node.default[:nginx][:user]           = "www-data"
node.default[:nginx][:config_flags]   = [
  "--sbin-path=#{node[:nginx][:binary_path]}",
  "--conf-path=#{node[:nginx][:conf_path]}",
  "--pid-path=#{node[:nginx][:pid_path]}",
  "--error-log-path=#{node[:nginx][:error_log_path]}",
  "--http-log-path=#{node[:nginx][:http_log_path]}",
  "--user=#{node[:nginx][:user]}",
  "--with-http_ssl_module"
]
node.default[:nginx][:passenger_pool_size] = 8

remote_file "#{Chef::Config[:file_cache_path]}/nginx-#{node[:nginx][:version]}.tar.gz" do
  source "http://nginx.org/download/nginx-#{node[:nginx][:version]}.tar.gz"
  action :create_if_missing
end

nginx_src_dir = bash "extract_nginx_source" do
  cwd Chef::Config[:file_cache_path]
  code <<-EOH
    tar zxf nginx-#{node[:nginx][:version]}.tar.gz
  EOH
  creates node[:nginx][:src_dir]
end

###############################
# Run the passenger installer #
###############################

package "libcurl4-openssl-dev"

execute "install_passenger_and_nginx" do
  command [
    node[:nginx][:installer],
    "--auto",
    "--prefix=#{node[:nginx][:install_path]}", 
    "--nginx-source-dir=#{node[:nginx][:src_dir]}",
    "--extra-configure-flags=\"#{node[:nginx][:config_flags].join(" ")}\""
  ].join(" ")

  creates node[:nginx][:binary_path]
end

template "/etc/init.d/nginx" do
  source "nginx.init.erb"
  owner "root"
  group "root"
  mode "0755"
end

###################
# Configure nginx #
###################

template node[:nginx][:conf_path] do
  source "nginx.conf.erb"
  owner "root"
  group "root"
  mode "0755"
  notifies :restart, 'service[nginx]'
end

service "nginx" do
  supports :status => true, :restart => true, :reload => true
  action :enable
  subscribes :restart, resources(:execute => "install_passenger_and_nginx")
end

logrotate_app "nginx" do
  path     "#{node[:nginx][:install_path]}/logs/access.log"
  rotate   7
  size     "5M"
end

include_recipe "monit"

template "/etc/monit/conf.d/nginx" do
	source   "monit"
	notifies :restart, "service[monit]"
end
