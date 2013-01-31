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

The ```base_container_template``` (for e.g.) can be built with this command:

```bin/bombay build container base_container_template```

will build a container called ruby_container_template in
```/var/lib/lxc/base_container_template``` with the ip 192.168.254.254

If you need to SSH into a container to poke around and see what's what,
you can issue the following command:

```ssh -i ~/.ansible/bombay action@192.168.254.254```

## Releasing a container

Once a container is built using the steps above, you can *release* it.
Releasing means that the container is tar'red and gzip'ped and uploaded
to S3, so that they can be downloaded by the box hosts.

Files will be suffixed with the timestamp of release.

You need to have ```s3cmd``` installed with your AWS credentials filled
in in ~/.s3cfg

To release a ```base_container_template```, issue this command:

```bin/bombay build container base_container_template --deploy```

## Building a template

```
bin/bombay build template ruby_template
```

## Releasing a template

```
bin/bombay build template ruby_template --deploy
```

After this, update the template version references in ansible playbooks

## Provisioning a new server on AWS

To provision a new server on AWS, run this command:

``` sh
bin/bombay build server rainbow
```

# Dashboard
To build the dashboards, run

```
bin/bombay dashboard
```
