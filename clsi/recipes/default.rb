# Cookbook Name:: clsi
# Recipe:: default
#
# Copyright 2012, ScribTeX

node.default[:clsi][:install_directory] = "/var/www/clsi"
node.default[:clsi][:user]              = "www-data"

package "git-core"

if node[:clsi][:user] == "www-data" then
  directory "/var/www" do
    owner "www-data"
  end
end

directory node[:clsi][:install_directory] do
  owner     node[:clsi][:user]
  recursive true
end

deploy "/var/www/clsi" do
  repo     "git://github.com/scribtex/clsi.git"
  revision "master"
  user     node[:clsi][:user]
end
