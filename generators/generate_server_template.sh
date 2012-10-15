#!/bin/bash
[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

server_name=${1}

if [ -d servers/${server_name} ]; then
	echo "A server template with this name already exists"
	exit 1
fi

mkdir -p servers/${server_name}/plays
mkdir -p servers/${server_name}/files
mkdir -p servers/${server_name}/templates
mkdir -p servers/${server_name}/tasks

touch servers/${server_name}/plays/.gitkeep
touch servers/${server_name}/files/.gitkeep
touch servers/${server_name}/templates/.gitkeep
touch servers/${server_name}/tasks/.gitkeep

main_yml=servers/${server_name}/plays/main.yml

cat generators/server_play_template.yml > ${main_yml}

sed -i "s/BOMBAY_SERVER_TEMPLATE/${server_name}/" ${main_yml}

echo -e "\n\n[${server_name}]" >> config/hosts.servers.development
echo -e "\n\n[${server_name}]" >> config/hosts.servers.production
echo -e "\n\n[${server_name}]" >> config/hosts.servers.staging
echo -e "\n\n[${server_name}]" >> config/hosts.servers.test

