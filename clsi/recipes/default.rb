# Cookbook Name:: clsi
# Recipe:: default
#
# Copyright 2012, ScribTeX

node.default[:clsi][:install_directory]   = "/var/www/clsi"
node.default[:clsi][:chroot_directory]    = File.join(node[:clsi][:install_directory], "/shared/latexchroot")
node.default[:clsi][:user]                = "www-data"
node.default[:clsi][:database][:name]     = "clsi"
node.default[:clsi][:database][:user]     = "clsi"
node.default[:clsi][:database][:password] = ""

node.default[:clsi][:chrooted_binaries] = Hash[ ["pdflatex", "latex", "xelatex", "bibtex", "makeindex", "dvipdf", "dvips"].map{|n|
  [n, "#{node[:clsi][:install_directory]}/shared/chrooted#{n}"]
}]

mysql_connection = ({:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']})

# Set up the database
mysql_database node[:clsi][:database][:name] do
  connection mysql_connection
  action     :create
end

mysql_database_user node[:clsi][:database][:user] do
  connection mysql_connection
  password   node[:clsi][:database][:password]
  action     :grant
end

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

deploy_revision node[:clsi][:install_directory] do
  repo     "git://github.com/scribtex/clsi.git"
  revision "master"
  user     node[:clsi][:user]

  environment ({
    "RAILS_ENV" => "production"
  })
  migrate           true
  migration_command "rake db:migrate"
  symlink_before_migrate ({
    "config/database.yml" => "config/database.yml",
    "config/config.yml"   => "config/config.yml",
    "config/mailer.yml"   => "config/mailer.yml"
  })
end

directory "#{node[:clsi][:install_directory]}/shared/log" do
  owner  node[:clsi][:user]
end
directory "#{node[:clsi][:install_directory]}/shared/config" do
  owner  node[:clsi][:user]
end

template "#{node[:clsi][:install_directory]}/shared/config/database.yml" do
  source "config/database.yml"
  owner  node[:clsi][:user]
end
template "#{node[:clsi][:install_directory]}/shared/config/config.yml" do
  source "config/config.yml"
  owner  node[:clsi][:user]
end

latex_chroot "#{node[:clsi][:chroot_directory]}" do
  texlive_directory "/usr/local/texlive"
  owner             "www-data"
end

for binary_name, destination in node[:clsi][:chrooted_binaries]
  execute "Build chrooted #{binary_name}" do
    command "gcc #{node[:clsi][:install_directory]}/current/chrootedbinary.c -o #{destination} " +
            "-DCHROOT_DIR='\"#{node[:clsi][:chroot_directory]}\"' -DCOMMAND='\"/usr/local/texlive/bin/i386-linux/#{binary_name}\"'"
    creates destination
  end

  file destination do
    owner "root"
    group node[:clsi][:user]
    mode  06750
  end 
end

directory "#{File.dirname(node[:nginx][:conf_path])}/sites"
 
template "#{File.dirname(node[:nginx][:conf_path])}/sites/clsi.conf" do
  source   "nginx.conf"
  notifies :restart, "service[nginx]" 
end

template "/etc/cron.hourly/clsi_clean_output_and_cache" do
  source "clean_output_and_cache.cron"
  mode   0755
end
