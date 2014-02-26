# -*- mode: ruby -*-
# vi: set ft=ruby :

IP = ENV['BOMBAY_INTERFACE'] || "33.33.33.10"

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  config.vm.hostname = "bombay-box"

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box      = 'opscode_ubuntu-12.04_chef-11.2.0'

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url  = "https://opscode-vm.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_chef-11.2.0.box"

  # Assign this VM to a host-only network IP, allowing you to access it
  # via the IP. Host-only networks can talk to the host machine as well as
  # any other machines on the same network, but cannot be accessed (through this
  # network interface) by any external networks.
  config.vm.network :private_network, ip: IP

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  config.vm.synced_folder "./", "/home/vagrant/bombay"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--cpus", "2"]
    v.customize ["modifyvm", :id, "--memory", "2048"]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end


  $script = """
apt-get update

version=2.0.0-p247
apt-get install -yy curl git-core vim-nox libxml2 libxml2-dev libxslt1-dev s3cmd lxc

su vagrant -l -c \"curl -L https://get.rvm.io | bash -s stable\"
su vagrant -l -c \"rvm list | grep ${version}\"

if [[ ! $? == 0 ]]; then
  su vagrant -l -c \"rvm install ${version}\"
fi

su vagrant -l -c \"rvm --default use ${version}\"
"""

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to exclusively install and copy to Vagrant's shelf.
  # config.berkshelf.only = []

  # An array of symbols representing groups of cookbook described in the Vagrantfile
  # to skip installing and copying to Vagrant's shelf.
  # config.berkshelf.except = []
  #
  config.vm.provision   "shell", inline: $script
end
