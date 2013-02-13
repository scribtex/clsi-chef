# Cookbook Name:: clsi
# Recipe:: default
#
# Copyright 2013, James Allen, ShareLaTeX

if node[:environment]
  # We are using data bags
  settings = data_bag_item("environments", node[:environment]).to_hash
  node.default[:clsi][:database][:name]       = settings["clsi"]["database"]["name"]
  node.default[:clsi][:database][:user]       = settings["clsi"]["database"]["user"]
  node.default[:clsi][:database][:password]   = settings["clsi"]["database"]["password"]
  node.default[:clsi][:token]                 = settings["clsi"]["token"]
  node.default[:clsi][:latex][:method]        = settings["clsi"]["latex"]["method"] || "package"
  node.default[:clsi][:latex][:source]        = settings["clsi"]["latex"]["source"]
  node.default[:clsi][:latex][:identity_file] = settings["clsi"]["latex"]["identity_file"]
  node.default[:mysql][:server_root_password] = settings["mysql"]["server_root_password"]
else
  node.default[:clsi][:latex][:method] = "package"
end

node.default[:clsi][:install_directory]   = "/var/www/clsi"
node.default[:clsi][:user]                = "www-data"

include_recipe "nginx-passenger"
package "rubygems"

# Database
# --------
gem_package "mysql"

mysql_connection = ({:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']})

mysql_database node[:clsi][:database][:name] do
  connection mysql_connection
  action     :create
end

mysql_database_user node[:clsi][:database][:user] do
  connection mysql_connection
  password   node[:clsi][:database][:password]
  action     :grant
end


# Set up directories
# ------------------

package "git-core"

directory node[:clsi][:install_directory] do
  owner     node[:clsi][:user]
  recursive true
end
directory "#{node[:clsi][:install_directory]}/shared" do
  owner  node[:clsi][:user]
  recursive true
end


directory "#{node[:clsi][:install_directory]}/shared/log" do
  owner  node[:clsi][:user]
  recursive true
end

directory "#{node[:clsi][:install_directory]}/shared/config" do
  owner  node[:clsi][:user]
  recursive true
end

directory "#{node[:clsi][:install_directory]}/shared/latexchroot" do
  owner  node[:clsi][:user]
  recursive true
end

# LaTeX environment
# -----------------
case node[:clsi][:latex][:method]
when "chroot"
  node[:clsi][:latex_chroot_dir] = "#{node[:clsi][:install_directory]}/shared/latexchroot"
  node[:clsi][:latex_compile_dir] = "#{node[:clsi][:latex_chroot_dir]}/compiles"
  node[:clsi][:latex_compile_dir_relative_to_chroot] = "compiles"
  binary_path = "#{node[:clsi][:install_directory]}/shared/chrooted"

  execute "Syncing latexchoot" do
    command [
      "rsync", "-av", "--delete",
      "-e", "'ssh -i #{node[:clsi][:latex][:identity_file]}'",
      node[:clsi][:latex][:source] + "/",
      node[:clsi][:latex_chroot_dir] + "/"
    ].join(" ")
    environment ({
      "RSYNC_PASSWORD" => node[:clsi][:latex][:rsync_password]
    })
  end
else
  package "texlive"
  binary_path = "/usr/bin/"
  node[:clsi][:latex_chroot_dir] = "#{node[:clsi][:install_directory]}/shared/latexchroot"
  node[:clsi][:latex_compile_dir] = "#{node[:clsi][:latex_chroot_dir]}/compiles"
  node[:clsi][:latex_compile_dir_relative_to_chroot] = node[:clsi][:latex_compile_dir]
end

node[:clsi][:binaries] = Hash[
  [
    "pdflatex", "latex", "xelatex", "bibtex", "makeindex", "dvipdf", "dvips"
  ].map{ |n|
    [n, "#{binary_path}#{n}"]
  }
]

if node[:clsi][:latex][:method] == "chroot"
  for binary_name, destination in node[:clsi][:binaries]
    if binary_name == "dvipdf"
      execute "Build chrooted #{binary_name}" do
        command "gcc #{node[:clsi][:install_directory]}/current/chrootedbinary.c -o #{destination} " +
                "-DCHROOT_DIR='\"#{node[:clsi][:chroot_directory]}\"' -DCOMMAND='\"/bin/#{binary_name}\"'"
        creates destination
      end
    else
      execute "Build chrooted #{binary_name}" do
        command "gcc #{node[:clsi][:install_directory]}/current/chrootedbinary.c -o #{destination} " +
                "-DCHROOT_DIR='\"#{node[:clsi][:chroot_directory]}\"' -DCOMMAND='\"/usr/local/texlive/bin/i386-linux/#{binary_name}\"'"
        creates destination
      end
    end

    file destination do
      owner "root"
      group node[:clsi][:user]
      mode  06750
    end 
  end
end

# Deploy CLSI Rails app
# ---------------------
template "#{node[:clsi][:install_directory]}/shared/config/database.yml" do
  source "config/database.yml"
  owner  node[:clsi][:user]
end
template "#{node[:clsi][:install_directory]}/shared/config/config.yml" do
  source "config/config.yml"
  owner  node[:clsi][:user]
end
file "#{node[:clsi][:install_directory]}/shared/log/production.log" do
  owner  node[:clsi][:user]
end

gem_package "rake" do
  version "0.9.2.2"
end
gem_package "rack" do
  version "1.1.3"
end

gem_package "rake" do
  version "0.9.2.2"
  gem_binary node[:ruby_enterprise][:gem_binary]
end
gem_package "rack" do
  version "1.1.3"
  gem_binary node[:ruby_enterprise][:gem_binary]
end


deploy_revision node[:clsi][:install_directory] do
  repo     "git://github.com/scribtex/clsi.git"
  revision "v1.1.4"
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

execute "Creating user for CLSI" do
  command "#{node[:clsi][:install_directory]}/current/script/runner #{node[:clsi][:install_directory]}/current/script/ensure_token_exists '#{node[:clsi][:token]}'"
  environment ({
    "RAILS_ENV" => "production"
  })
end


# Nginx and Passenger
# -------------------

directory "#{File.dirname(node[:nginx][:conf_path])}/sites"
 
template "#{File.dirname(node[:nginx][:conf_path])}/sites/clsi.conf" do
  source   "nginx.conf"
  notifies :restart, "service[nginx]" 
end

# Logging and monitoring
# ----------------------
template "/etc/cron.hourly/clsi_clean_output_and_cache" do
  source "clean_output_and_cache.cron"
  mode   0755
end

template "#{node[:clsi][:install_directory]}/shared/check.rb" do
  source "check.rb"
  mode   0755
end

template "/etc/cron.d/check_clsi" do
  source "cron.d/check_clsi.cron"
  mode   0755
end

template "/etc/logrotate.d/clsi" do
  source "logrotate"
  mode  0644
end
