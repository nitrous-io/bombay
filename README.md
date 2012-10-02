# Bombay

Bombay is action.io's Box Builder. This is a series of scripts which
lets us automate the creation of box templates which will be used to
create boxes for users.

## Meat of the Machine

Bombay heavily uses [Ansible](http://ansible.cc/), playbooks for containers go in the containers/ directory

## Building a container

```make build TEMPLATE=ruby_container_template```

will build a container called ruby_container_template in
```/var/lib/lxc/ruby_container_template``` with the ip 192.168.254.254

If you need to SSH into a container to poke around and see what's what,
you can issue the following command:

```ssh -i ~/.ansible/bombay action@192.168.254.254```
