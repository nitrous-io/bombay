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

	./setup/generate_container_template.sh $(container) $(ip) $(gateway)
	@echo "** Done **"
else ifdef server
	./setup/generate_server_template.sh $(server)
	@echo "** server template built in servers/$(server) . Done **"
else
	$(error Usage: make generate container=template_name ip=ip gateway=gateway)
endif


build:
ifdef container
	ANSIBLE_CONFIG=setup/ansible.container.cfg ansible-playbook containers/$(container)/plays/main.yml -i setup/hosts.containers
else ifdef server

ifndef env
	ANSIBLE_CONFIG=setup/ansible.server.cfg ansible-playbook servers/$(server)/plays/main.yml -e env=development -i setup/hosts.servers.development
else ifeq ($(env), development)
	ANSIBLE_CONFIG=setup/ansible.server.cfg ansible-playbook servers/$(server)/plays/main.yml -e env=$(env) -i setup/hosts.servers.$(env)
else
	ANSIBLE_CONFIG=setup/ansible.server.cfg ansible-playbook servers/$(server)/plays/main.yml -e env=$(env) -i setup/hosts.servers.$(env) -c ssh
endif

else
	$(error Usage: make container|server=name)
endif

release:
ifndef container
	$(error Usage: make release container=name)
else
	./setup/release.sh $(container)
endif

.SILENT: setup generate release

.PHONY: setup generate build release
