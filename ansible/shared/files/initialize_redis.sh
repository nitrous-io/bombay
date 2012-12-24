#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

redis_port=${1}

# Initialize redis script
#
# The redis structure is:
# - `aio:available_resources` and `aio:used_resources` will store list of ips
# - `aio:nwr:{ip}` will store a hash of gateway, interface name and port
#
# For example:
#   `aio:available_resources`: ["192.168.2.253"]
#   `aio:used_resources`: ["192.168.2.254"]
#   `aio:nwr:192.168.2.254`: { gateway: "192.168.2.1", interface: "br-lxc-2", port: "10001" } ( port is just for illustration, it may not be correct )
#
# This script should be indempotency i.e. can run multiple times without any
# side-effect.
luascript=$(cat <<EOF
local all_ips = {}
local used_resources = {}
local port_id = 0

-- set individual ip details
for i = 244, 254 do
  for j = 2, 254 do
    local interface = 'br-lxc-' ..i
    local ip = '192.168.' ..i.. '.' ..j
    local gateway = '192.168.' ..i.. '.1'
    local port = tostring(10000 + port_id)
    local key = 'aio:nwr:' ..ip

    -- re-insert the ip details
    redis.call('hmset', key, "gateway", gateway, "interface", interface, "port", port)
    all_ips[#all_ips+1] = ip
    port_id = port_id + 1
  end
end

-- remove all used ips from the pool
local used_ips = {}
local used_resources = {}

if redis.call('exists', 'aio:used_resources') == 1 then
  used_resources = redis.call('lrange', 'aio:used_resources', 0, -1)
  for j, used_ip in ipairs(used_resources) do
    -- assign the ip to used_ips list
    used_ips[#used_ips+1] = used_ip

    -- remove the ip from all_ips list
    for i,ip in ipairs(all_ips) do
      if ip == used_ip then
        table.remove(all_ips, i)
      end
    end
  end
else
  -- this should be run only once for transition state and removed later
  used_resources = redis.call('lrange', 'used_resources', 0, -1)

  local used_length = #used_resources
  for j = 1, used_length do
    local used_ip_hash = cjson.decode(used_resources[j])
    if used_ip_hash.ip then
      -- assign the ip to used_ips list
      used_ips[#used_ips+1] = used_ip_hash.ip

      -- remove the ip from all_ips list
      for i,ip in ipairs(all_ips) do
        if ip == used_ip_hash.ip then
          table.remove(all_ips, i)
        end
      end
    end
  end

  -- dont remove the old data, we will manually remove it after verification
end

redis.call('del', 'aio:available_resources')
for _,v in ipairs(all_ips) do
  redis.call('rpush', 'aio:available_resources', v)
end

redis.call('del', 'aio:used_resources')
for _,v in ipairs(used_ips) do
  redis.call('rpush', 'aio:used_resources', v)
end
EOF
)

redis-cli -p $redis_port eval "$luascript" 0
