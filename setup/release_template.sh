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
  rm -rf /tmp/${container_name}
fi

sudo cp -rf /var/lib/lxc/${container_name} /tmp/
sudo rm -rf /tmp/${container_name}/rootfs/home/action/.ssh
sudo rm -rf /tmp/${container_name}/rootfs/var/log/*

gzipped_file_name=${container_name}_${time_of_build}.tar.gz

cd /tmp
sudo bash -c "tar cvf - ${container_name} | gzip -c > ${gzipped_file_name}"

# Upload to S3
s3cmd put /tmp/${gzipped_file_name} s3://bombay-apse.action.io/${gzipped_file_name}

# Cleanup
sudo rm -rf /tmp/${container_name}*
