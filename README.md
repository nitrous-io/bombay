# Bombay

Bombay is action.io's Box Builder. This is a series of scripts which
lets us automate the creation of box templates which will be used to
create boxes for users.

## Meat of the Machine

Bombay heavily uses [Ansible](http://ansible.cc/), hence the directory playbooks.
You need to log into rj-dev's machine to issue ansible commands.

## Commands tested working

### Vanilla container creation

Syntax: 

    ansible-playbook <playbook> -e "extra_options=value"

Vanilla container creation:

    cd ~/bombay/playbooks
    ansible-playbook lxc/plays/vanilla_container.yml

To destroy an existing vanilla container before creating a new one:

    ansible-playbook lxc/plays/vanilla_container.yml -e "destroy=y"

A vanilla container is used for setting up a base container to where to clone customized containers from.

### Ruby container creation for templating

Creating a ruby container for templating

    ansible-playbook lxc/plays/ruby_templater.yml -e "destroy=y cont=ruby_template"

Where "cont" is the container name. Note that it's required to name the container as 'ruby_template'. 
The name is passed as a variable in ansible playbooks which determines how the playbook behaves.
