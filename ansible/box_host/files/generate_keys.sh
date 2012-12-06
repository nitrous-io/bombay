#!/bin/bash

for box in $(redis-cli -p 65000 HKEYS aio:boxes)
do
  if [ -d /var/lib/lxc/${box}/rootfs/ ]; then
    chroot /var/lib/lxc/${box}/rootfs su action -c "/usr/bin/ssh-keygen -N '' -f /home/action/.ssh/id_rsa -b 1024 -t rsa -q"
    echo "Generated Key for ${box}"
  fi
done
