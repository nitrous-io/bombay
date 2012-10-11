#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

redis_port=${1}

listlength="`redis-cli -p ${redis_port} llen available_ips`"
if [ "$listlength" -eq "0" ]
  then
    for i in {2..254}
    do
      redis-cli -p $redis_port rpush available_ips "192.168.254.${i}"
    done
fi

listlength="`redis-cli -p ${redis_port} llen available_ports`"
if [ "$listlength" -eq "0" ]
  then
    for i in {10000..10253}
    do
      redis-cli -p $redis_port rpush available_ports $i
    done
fi

