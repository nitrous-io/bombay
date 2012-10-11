#!/bin/bash

#!/bin/bash
[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

container_name=${1}
time_of_build=`date +%s`

if [ ! -d /var/lib/lxc/${container_name} ]; then
	echo "You do not seem to have built this container, run make build TEMPLATE=${container_name} to build the template"
	exit 1
fi

# Remove remnants of the previoous release
if [ -d /tmp/${container_name} ]; then
  sudo rm -rf /tmp/${container_name}
fi

sudo cp -pr /var/lib/lxc/${container_name} /tmp/

# Remove extraneous features from the template
sudo rm -rf /tmp/${container_name}/rootfs/home/action/.ssh
sudo rm -rf /tmp/${container_name}/rootfs/var/log/*
sudo rm -rf /tmp/${container_name}/rootfs/var/cache/apt/archives/*

# Add VERSION
echo $time_of_build > /tmp/${container_name}/VERSION

gzipped_file_name=${container_name}_${time_of_build}.tar.gz

cd /tmp
sudo tar cpvzf ${gzipped_file_name} ${container_name}

# Upload to S3
s3cmd put /tmp/${gzipped_file_name} s3://bombay-apse.action.io/${gzipped_file_name}

# Cleanup
sudo rm -rf /tmp/${container_name}*

echo "File is available in s3://bombay-apse.action.io/${gzipped_file_name}"
