#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
set -o errexit
shopt -s nullglob

lxc_root='/var/lib/lxc'
container_template='base_container_template'
box_name=${1}
box_path=${lxc_root}/${box_name}
box_delta_path=${box_path}_delta
container_path=${lxc_root}/${container_template}
mount_options=rw,upperdir=${box_delta_path},lowerdir=${container_path}
action_uid=`chroot ${container_path}/rootfs /usr/bin/id -u action`
action_gid=`chroot ${container_path}/rootfs /usr/bin/id -g action`

mkdir -p ${box_path}
mkdir -p ${box_delta_path}
mount -n -t overlayfs -o ${mount_options} none ${box_path}

(
  flock -x 200
  sed -i "s/${container_template}/${box_name}/g" ${box_path}/config
  echo "${box_name}" > ${box_path}/rootfs/etc/hostname
) 200>/var/lock/boxer.mount_container

lxc-start -n ${box_name} -d
lxc-wait -n ${box_name} -s RUNNING
