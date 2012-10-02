ansible_version = 0.7.1

# setup install ansible on your system by downloading the relevant version from GitHub
setup:
	@echo 'Downloading ansible $(ansible_version) from GitHub...'
	wget https://github.com/downloads/ansible/ansible/ansible-$(ansible_version).tar.gz --output-document=/tmp/ansible-$(ansible_version).tar.gz --quiet 
	@echo 'Expanding ansible $(ansible_version)'
	tar -zxvf /tmp/ansible-$(ansible_version).tar.gz --directory=/tmp
	@echo 'Setting up ansible $(ansible_version)...'
	cd /tmp/ansible-$(ansible_version) && sudo python setup.py install
	@echo 'Symlinking ansible.cfg to ~/.ansible.cfg and hosts to /etc/ansible/hosts'
	sudo mkdir -p /etc/ansible
	ln -s $(PWD)/setup/ansible.cfg ~/.ansible.cfg
	sudo ln -s $(PWD)/setup/hosts /etc/ansible/hosts
	@echo "** Done **"

generate:
ifndef TEMPLATE
	$(error Usage: make generate TEMPLATE=template_name IP=ip GATEWAY=gateway)
endif

ifndef IP
	$(error Usage: make generate TEMPLATE=template_name IP=ip GATEWAY=gateway)
endif

ifndef GATEWAY
	$(error Usage: make generate TEMPLATE=template_name IP=ip GATEWAY=gateway)
endif

	./setup/generate_template.sh $(TEMPLATE) $(IP) $(GATEWAY)
	@echo "** Done **"

build:
ifndef TEMPLATE
	$(error Usage: make build TEMPLATE=template_name)
else
	ansible-playbook containers/$(TEMPLATE)/plays/main.yml
endif

.SILENT: setup generate

.PHONY: setup generate
