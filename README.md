Chef cookbooks for the CLSI
===========================

Chef is a server configuration tool which lets you quickly and easily set up and
replicate a server. These files provide the necessary instructions to set up a server
running an instance of the Common LaTeX Service Interface.

Usage
-----

On a fresh install of Ubuntu 10.04, run the following commands as root to install chef
and some necessary utilities: 

    echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | tee /etc/apt/sources.list.d/opscode.list
    mkdir -p /etc/apt/trusted.gpg.d
    gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
    gpg --export packages@opscode.com | tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null 
    apt-get update
    apt-get upgrade
    apt-get install chef git-core build-essential
    
Now checkout this repository to your chef directory:

    cd /var/chef
    git clone git://github.com/scribtex/clsi-chef.git cookbooks

You will need to write tell chef about some server specific configs, so in /var/chef/clsi.json write:

    {
      "mysql" : {
        "server_root_password" : "potatoes"
      },
      "clsi" : {
        "host" : "clsi.example.com",
        "database" : {
          "name"     : "clsi",
          "user"     : "clsi",
          "password" : "bananas"
        }
      },
      "run_list" : [ "mysql::server", "mysql::client", "clsi" ]
    }

Then finally run chef to set up the server (this may take a long time the first time since 
TexLive needs to be downloaded:

    chef-solo -j clsi.json
