Chef cookbooks for the CLSI
===========================

Chef is a server configuration tool which lets you quickly and easily set up and
replicate a server. These files provide the necessary instructions to set up a server
running an instance of the Common LaTeX Service Interface.

Usage
-----

*Note that only Ubuntu 12.04 is currently supported. This configuration may well work with
other systems but it hasn't been tested*

On a fresh install of Ubuntu 12.04, run the following commands as root to install chef
and some necessary utilities: 

    echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | tee /etc/apt/sources.list.d/opscode.list
    mkdir -p /etc/apt/trusted.gpg.d
    gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
    gpg --export packages@opscode.com | tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null 
    apt-get update
    apt-get upgrade
    apt-get install chef git-core build-essential
    
Now checkout this repository to a directory of your choice:

    git clone git://github.com/scribtex/clsi-chef.git

You will need to write tell chef about some server specific configs. Modify node.json:

    {
      "clsi" : {
        "host" : "clsi.example.com",
        "token" : "clsi-token",
        "database" : {
          "name"     : "clsi",
          "user"     : "clsi",
          "password" : "bananas"
        }
      },
      "mysql" : {
        "server_root_password" : "potatoes",
        "server_repl_password" : "potatoes",
        "server_debian_password" : "potatoes"
      },
      "run_list" : [ "mysql::server", "mysql::client", "mysql::ruby", "clsi" ]
    }

Hopefully the meaning of these attributes is clear. `clsi.host` should be set to where your server
can be found, either an IP address or the DNS entry. This is used to tell clients where they can
find the resources that have been generated. `clsi.token` should be a unique string that will identify
your client. It is like a password, and the token that you provide will be set up as the default user.

Then finally run chef to set up the server (this may take a long time the first time since 
TexLive needs to be downloaded, and nginx and ruby-enterprise compiled):

    chef-solo -j node.json -c solo.rb

Users
-----

Clients identify themselves to the CLSI with a token. You can set a default token in the config as
shown above, but to create additional users you need to use the command line:

    cd /var/www/clsi/current
    script/console production
    >> User.create :name => "Jane Bloggs", :email => "jame@example.com"

A token is generated automatically and will be displayed when the user is created.
