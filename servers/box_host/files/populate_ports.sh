#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

redis_port=${1}

for i in {10000..10250}
do
  redis-cli -p $redis_port rpush available_ports $i
done

