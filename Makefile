ansible_version = 0.7.1

# setup install ansible on your system by downloading the relevant version from GitHub
setup:
	wget https://github.com/downloads/ansible/ansible/ansible-$(ansible_version).tar.gz --output-document=/tmp/ansible-$(ansible_version).tar.gz --quiet 
	tar -zxvf /tmp/ansible-$(ansible_version).tar.gz --directory=/tmp
	cd /tmp/ansible-$(ansible_version) && sudo python setup.py install
	sudo mkdir -p /etc/ansible
	sudo cp setup/ansible.cfg /etc/ansible/ansible.cfg
	sudo cp setup/hosts /etc/ansible/hosts
	sudo chown root:root /etc/ansible/ansible.cfg
	sudo chown root:root /etc/ansible/hosts
	echo "Done"

.PHONY: setup
