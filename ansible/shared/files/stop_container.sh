#!/bin/bash
[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
set -o errexit
shopt -s nullglob

name=${1}
lxc_root='/var/lib/lxc'
box_path=${lxc_root}/${name}

if [ -d ${box_path} ]; then
  lxc-stop -n ${name}
  lxc-wait -n ${name} -s STOPPED
  echo 'Flushing IPTables'
  iptables -t nat -F
fi
