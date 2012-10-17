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

```make build container=ruby_container_template```

will build a container called ruby_container_template in
```/var/lib/lxc/ruby_container_template``` with the ip 192.168.254.254

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

To release a ```ruby_container_template```, issue this command:

``` make release container=ruby_container_template```

## Creating a new container

If you want to create a new container template (say for php), you can do
this by issuing this command:

```make generate container=php_container_template ip=192.168.254.253 gateway=192.168.254.1```

The ```ip``` is the IP that will be used by Ansible to SSH into the container. The ```ip``` must be in the same subnet as the ```gateway```.

Once you run the command, the containers/php_container_template folder will be created and you can start editing playbooks, tasks, files and templates within it.

## Provisioning a new server on AWS

To provision a new server on AWS, run this command:

``` sh
make provision env=staging server=rainbow region=ap-southeast-1 size=m1.small
```

This will create an instance in the stated AWS region and instance size. The environment and server options sets the correct security policy and other options.

## Building the server with Ansible

After the new instance is built, we need to install the necessary packages using Ansible. Ansible will ssh into the instance and perform the necessary installations.

``` sh
make build env=staging server=rainbow
```

## Boostrap with Capistrano

The last step would be to boostrap the application with Capistrano. Run the command below:

``` sh
cap staging deploy
```

This will setup the instance for deployment with Capistrano.

## Troubleshooting

If you get this error while building a box

```
fatal: [192.168.254.254] => Traceback (most recent call last):
  File
"/usr/local/lib/python2.7/dist-packages/ansible/runner/__init__.py",
line 427, in _executor
    exec_rc = self._executor_internal(host)
  File
"/usr/local/lib/python2.7/dist-packages/ansible/runner/__init__.py",
line 478, in _executor_internal
    return self._executor_internal_inner(host, inject, port)
  File
"/usr/local/lib/python2.7/dist-packages/ansible/runner/__init__.py",
line 595, in _executor_internal_inner
    self._delete_remote_files(conn, tmp)
  File
"/usr/local/lib/python2.7/dist-packages/ansible/runner/__init__.py",
line 152, in _delete_remote_files
    raise Exception("not going to happen")
Exception: not going to happen
```

just rerun the ```make build container``` task (it is idempotent and so will skip
over steps which have already been completed). This bug is supposedly
fixed in the upcoming 0.8 release of ansible.

### Skipping installation prompts

If your installation screen has prompts, you can prevent that by adding the environment variable

```
DEBIAN_FRONTEND=noninteractive
```

Example

```
DEBIAN_FRONTEND=noninteractive apt-get -y install nagios3 nagios-nrpe-plugin
```
