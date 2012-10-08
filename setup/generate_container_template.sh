#!/bin/bash

#!/bin/bash
[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

container_name=${1}
ip=${2}
gateway=${3}

if [ -d containers/${container_name} ]; then
	echo "A container template with this name already exists"
	exit 1
fi

grep -q -Rn "${ip}" --include=interfaces /var/lib/lxc > /dev/null 2>&1

if [ $? == 0 ]; then
	echo -e "You have a container with this IP ${ip} in /var/lib/lxc\nChoose another IP."
	exit 1
fi

mkdir -p containers/${container_name}/plays
mkdir -p containers/${container_name}/files
mkdir -p containers/${container_name}/templates
mkdir -p containers/${container_name}/tasks

touch containers/${container_name}/plays/.gitkeep
touch containers/${container_name}/files/.gitkeep
touch containers/${container_name}/templates/.gitkeep
touch containers/${container_name}/tasks/.gitkeep

main_yml=containers/${container_name}/plays/main.yml

cat setup/play_template.yml > ${main_yml}

sed -i "s/BOMBAY_CONTAINER_TEMPLATE/${container_name}/" ${main_yml}
sed -i "s/BOMBAY_IP/${ip}/" ${main_yml}
sed -i "s/BOMBAY_GATEWAY/${gateway}/" ${main_yml}

echo -e "\n\n[${container_name}]\n${ip}" >> setup/hosts




