ansible_version = 0.7.1

# setup install ansible on your system by downloading the relevant version from GitHub
setup:
	@echo 'Installing ansible dependencies'
	sudo apt-get -yy install python-paramiko python-yaml python-jinja2 python-simplejson
	@echo 'Downloading ansible $(ansible_version) from GitHub...'
	wget https://github.com/downloads/ansible/ansible/ansible-$(ansible_version).tar.gz --output-document=/tmp/ansible-$(ansible_version).tar.gz --quiet
	@echo 'Expanding ansible $(ansible_version)'
	tar -zxvf /tmp/ansible-$(ansible_version).tar.gz --directory=/tmp
	@echo 'Setting up ansible $(ansible_version)...'
	cd /tmp/ansible-$(ansible_version) && sudo python setup.py install
	@echo "** Done **"

generate:
ifdef container
	ifndef ip
		$(error Usage: make generate container=template_name ip=ip gateway=gateway)
	endif

	ifndef gateway
		$(error Usage: make generate container=template_name ip=ip gateway=gateway)
	endif

	./generators/generate_container_template.sh $(container) $(ip) $(gateway)
	@echo "** Done **"
else ifdef server
	./generators/generate_server_template.sh $(server)
	@echo "** server template built in ansible/servers/$(server) . Done **"
else
	$(error Usage: make generate container=template_name ip=ip gateway=gateway)
endif


build:
ifdef container
	ANSIBLE_CONFIG=ansible/config/ansible.container.cfg ansible-playbook ansible/containers/$(container)/plays/main.yml -i ansible/config/hosts.containers --private-key=$(HOME)/.ansible/bombay
else ifdef server

ifndef env
	ANSIBLE_CONFIG=ansible/config/ansible.server.cfg ansible-playbook ansible/servers/$(server)/plays/main.yml -e env=development -i ansible/config/hosts.servers.development -c local
else ifeq ($(env), development)
	ANSIBLE_CONFIG=ansible/config/ansible.server.cfg ansible-playbook ansible/servers/$(server)/plays/main.yml -e env=$(env) -i ansible/config/hosts.servers.$(env) -c local
else
	ANSIBLE_CONFIG=ansible/config/ansible.server.cfg ansible-playbook ansible/servers/$(server)/plays/main.yml -e env=$(env) -i ansible/config/hosts.servers.$(env) --private-key=$(HOME)/.ec2/ap-southeast-1-keypair.pem
endif

else
	$(error Usage: make container|server=name)
endif

release:
ifndef container
	$(error Usage: make release container=name)
else
	./generators/release_container.sh $(container)
endif

provision:
ifndef server
	$(error Usage: make provision env=staging server=rainbow region=ap-southeast-1 size=m1.small)
endif

ifndef env
	$(error Usage: make provision env=staging server=rainbow region=ap-southeast-1 size=m1.small)
endif

ifndef size
	$(error Usage: make provision env=staging server=rainbow region=ap-southeast-1 size=m1.small)
endif

ifndef region
	$(error Usage: make provision env=staging server=rainbow region=ap-southeast-1 size=m1.small)
endif

	./provisioning/provision.rb $(env) $(server) $(region) $(size)

.SILENT: setup generate release build

.PHONY: setup generate build release
