# Bombay

Bombay is action.io's Box Builder. This is a series of scripts which
lets us automate the creation of box templates which will be used to
create boxes for users.

## Installation Instructions

### First boot into vagrant

Install [Vagrant](http://vagrantup.com)

```
vagrant up
vagrant ssh
```

You will need ansible 1.2.2. This command should get you up to start

`bin/bombay setup`

## Building a container

The `base_container_template` (for e.g.) can be built with this command:

`bin/bombay build container base_container_template`

will build a container called ruby_container_template in
`/var/lib/lxc/base_container_template` with the ip 192.168.254.254

If you need to SSH into a container to poke around and see what's what,
you can issue the following command:

`ssh -i ~/.ansible/bombay action@192.168.254.254`

## Releasing a container

Once a container is built using the steps above, you can *release* it.
Releasing means that the container is tar'red and gzip'ped and uploaded
to S3, so that they can be downloaded by the box hosts.

Files will be suffixed with the timestamp of release.

You need to have `s3cmd` installed with your AWS credentials filled
in in ~/.s3cfg

To release a `base_container_template`, issue this command:

`bin/bombay build container base_container_template --deploy`

## Building a template

`bin/bombay build template ruby_template`

## Releasing a template

`sudo bin/bombay build template ruby_template --deploy`

After this, update the template version references in boxhost_cookbook
