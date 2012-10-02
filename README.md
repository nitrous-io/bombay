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
