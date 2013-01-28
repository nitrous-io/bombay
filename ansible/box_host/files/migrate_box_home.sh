#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
set -o errexit
shopt -s nullglob

redis_port=${1}
lxc_root=/var/lib/lxc
quoted_lxc_root='\/var\/lib\/lxc\/'
container_template=base_container_template
container_template_path=${lxc_root}/${container_template}

for box in $(redis-cli -p $redis_port HKEYS aio:boxes)
do
  base_template=`cat /etc/fstab | grep -i ${box} | sed 's/.*\lowerdir=\([a-z_\/]*\).*/\1/'`
  box_path=${lxc_root}/${box}
  box_delta_path=${box_path}_delta
  container_path=${lxc_root}/${container_template}

  if [ -d ${base_template}/rootfs/ ] && [ -d $box_delta_path ]; then
    mount_options=rw,upperdir=${box_delta_path},lowerdir=${container_path}
    fstab_config="none ${box_path} overlayfs ${mount_options} 0 0"

    echo "Stopping ${box}"
    lxc-stop -n ${box}
    lxc-wait -n ${box} -s STOPPED

    if [[ `cat /proc/mounts | grep "${box_path}\>"` ]]; then
      echo "Unmounting ${box_path}"
      umount ${box_path}
    fi

    echo "Migrating home dir for box: ${box} from base template: ${base_template}"
    rsync -auzH ${base_template}/rootfs/home/action /var/lib/lxc/${box}_delta/rootfs/home
    echo "Migrated home dir for box: ${box}"

    echo 'Removing line from /etc/fstab'
    sed -i "/${quoted_lxc_root}${box}\b/d" /etc/fstab

    echo "Moving base to base_container_template"
    mount -n -t overlayfs -o ${mount_options} none ${box_path}
    echo "${fstab_config}" >> /etc/fstab
    echo "Moved base to base_container_template"

    lxc-start -n ${box} -d
    echo "Started: ${box}"
    echo "Finished ${box}"
  fi
done
