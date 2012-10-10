#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

redis_port=${1}

for i in {2..254}
do
  redis-cli -p $redis_port rpush available_ips "192.168.254.${i}"
done
