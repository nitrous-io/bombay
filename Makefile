ansible_version = 0.7.1

# setup install ansible on your system by downloading the relevant version from GitHub
setup:
	@echo 'Downloading ansible $(ansible_version) from GitHub...'
	wget https://github.com/downloads/ansible/ansible/ansible-$(ansible_version).tar.gz --output-document=/tmp/ansible-$(ansible_version).tar.gz --quiet 
	@echo 'Expanding ansible $(ansible_version)'
	tar -zxvf /tmp/ansible-$(ansible_version).tar.gz --directory=/tmp
	@echo 'Setting up ansible $(ansible_version)...'
	cd /tmp/ansible-$(ansible_version) && sudo python setup.py install
	@echo 'Copying .cfg and hosts to /etc/ansible'
	sudo mkdir -p /etc/ansible
	cp setup/ansible.cfg $(HOME)/.ansible.cfg
	sudo cp setup/hosts /etc/ansible/hosts
	sudo chown root:root /etc/ansible/hosts
	@echo "** Done **:"

generate:
ifndef TEMPLATE
	$(error Usage: make generate TEMPLATE=template_name)
else
	mkdir -p playbooks/$(TEMPLATE)
	mkdir -p playbooks/$(TEMPLATE)/files
	mkdir -p playbooks/$(TEMPLATE)/templates
	mkdir -p playbooks/$(TEMPLATE)/plays
	mkdir -p playbooks/$(TEMPLATE)/tasks
	@echo "Created playbooks/$(TEMPLATE)"
	@echo "** Done **"
endif


.SILENT: setup generate

.PHONY: setup generate
