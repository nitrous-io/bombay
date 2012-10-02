# Bombay

Bombay is action.io's Box Builder. This is a series of scripts which
lets us automate the creation of box templates which will be used to
create boxes for users.

## Installation Instructions

This has been tested only on *Ubuntu 12.04 Precise* YMMV if you try it
on another platform.

Make sure you have ```build-essential``` and ```python``` setup on your
machine. ```python``` is typically setup on Ubuntu by default;
installing build-essential is as easy as

```sudo apt-get install build-essential```

```build-essential``` installs your build tools such as gcc, g++ and
make.

To setup the right environment for Bombay, including ansible, run

```make setup```

## Building a container

The ```ruby_container_template``` (for e.g.) can be built with this command:

```make build TEMPLATE=ruby_container_template```

will build a container called ruby_container_template in
```/var/lib/lxc/ruby_container_template``` with the ip 192.168.254.254

If you need to SSH into a container to poke around and see what's what,
you can issue the following command:

```ssh -i ~/.ansible/bombay action@192.168.254.254```

## Creating a new container

If you want to create a new container template (say for php), you can do
this by issuing this command:

```make generate TEMPLATE=php_container_template IP=192.168.254.253 GATEWAY=192.168.254.1```

The ```IP``` is the IP that will be used by Ansible to SSH into the container. The ```IP``` must be in the same subnet as the ```GATEWAY```.

Once you run the command, the containers/php_container_template folder will be created and you can start editing playbooks, tasks, files and templates within it.
