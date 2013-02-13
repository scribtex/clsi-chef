require 'rubygems'
require 'json'

UP_FILE = "<%= node[:clsi][:install_directory] %>/current/public/up.html"
RESTART_NGINX_COMMAND = '/etc/init.d/nginx restart'
RESTART_MYSQL_COMMAND = '/etc/init.d/mysql restart'

request = {
  :compile => {
    :token => "banana",
    :resources => [{
      :path => "main.tex",
      :content => "\\documentclass{article}\\begin{document}Hello world\\end{document}"
    }]
  }
}

raw_response = `curl -s --data '#{request.to_json}' "http://<%= node[:clsi][:host] %>/clsi/compile?format=json"`

def failed!
  if File.exist?(UP_FILE)
    FileUtils.rm(UP_FILE)
  end
  system(RESTART_NGINX_COMMAND)
  system(RESTART_MYSQL_COMMAND)
end

def success!
  FileUtils.touch(UP_FILE)
end

begin
  response = JSON.parse(raw_response)
rescue
  failed!
end

if (response["compile"] and response["compile"]["output_files"]) 
  success!
else
  failed!
end
