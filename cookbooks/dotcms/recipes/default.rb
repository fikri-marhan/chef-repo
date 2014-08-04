#
# Cookbook Name:: dotcms
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

#install java
include_recipe "java"

#install mysql
include_recipe "mysql::server"

#create database and db user
include_recipe "database::mysql"
dotCMS_database_info = {
    :host     => 'localhost',
    :username => 'root',
    :password => node['mysql']['server_root_password']
}

mysql_database node['dotCMS']['database_name'] do
  connection dotCMS_database_info
  action :create
end

mysql_database_user node['dotCMS']['database_username'] do 
	connection dotCMS_database_info
	password node['dotCMS']['database_password']
	action :create
end

mysql_database_user node['dotCMS']['database_username'] do 
	connection dotCMS_database_info
	password node['dotCMS']['database_password']
	database_name node['dotCMS']['database_name']
	privileges [:all]
	action :grant
end

# create a user for this app
user node['dotCMS']['user'] do
  supports :manage_home => true
  comment "dotCMS app user"
  home "/home/#{node['dotCMS']['user']}"
  shell "/bin/bash"
  password "$1$4jnhdh.c$sUczfPJ83yG5UWfYtGrzT1" #ten20304050
end


# install dot cms app
src_filename = "dotcms_#{node['dotCMS']['version']}.tar.gz"
src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"
extract_path = "/home/#{node['dotCMS']['user']}/dotcms_app"

remote_file src_filepath do 
	source node['dotCMS']['url'] + "/" + src_filename
	owner 'root'
	group 'root'
end

bash "deploy_dot_cms" do
  cwd ::File.dirname(src_filepath)
  code <<-EOH
    mkdir -p #{extract_path}
    tar -zxvf #{src_filename} -C #{extract_path}
    cd #{extract_path}/dotserver
    chmod 755 ./bin/*.sh
    chmod 755 ./tomcat/bin/*.sh
    EOH
  not_if { ::File.exists?("extract_path") }
end

template "#{extract_path}/dotserver/tomcat/conf/Catalina/localhost/ROOT.xml" do 
	source "ROOT.xml.erb"
	variables({
		:db_name => node['dotCMS']['database_name'],
		:db_username => node['dotCMS']['database_username'],
		:db_password => node['dotCMS']['database_password']
		})
end

template "#{extract_path}/dotserver/tomcat/conf/server.xml" do 
	source "server.xml.erb"
	variables({
		:app_port => node['dotCMS']['port']
		})
end

bash "restart_dotcms" do
  code <<-EOH
    cd #{extract_path}/dotserver
    ./bin/shutdown.sh
    rm -rf /tmp/dotserver.pid
    ./bin/startup.sh
    EOH
  only_if { ::File.exists?("/tmp/dotserver.pid") }
end

bash "start_dotcms" do
  code <<-EOH
    cd #{extract_path}/dotserver
    ./bin/startup.sh
    EOH
  not_if { ::File.exists?("/tmp/dotserver.pid") }
end