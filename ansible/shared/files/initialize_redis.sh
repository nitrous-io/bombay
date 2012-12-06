#!/bin/bash

[ -n "$DEBUG" ] && set -o xtrace
set -o nounset
shopt -s nullglob

redis_port=${1}

luascript=$(cat <<EOF
local resources = {}
local used_resources = {}
local port_id = 0

for i = 244, 254 do
  for j = 2, 254 do
    local interface = ''
    local ip = '192.168.' ..i.. '.' ..j
    local gateway = '192.168.' ..i.. '.1'
    if i == 254 then
      interface = 'br-lxc'
    else
      interface = 'br-lxc-' ..i
    end
    local port = tostring(10000 + port_id)
    port_id = port_id + 1
    resources[#resources+1] = {ip=ip, gateway=gateway, interface=interface, port=port}
  end
end

local used_ips = redis.call('lrange', 'used_ips', 0, -1)
local used_length = #used_ips
for j = 1, used_length do
  local new_length = #resources
  for i = 1, new_length do
    if resources[i] then
      if resources[i].ip == used_ips[j] then
        table.insert(used_resources, resources[i])
        table.remove(resources, i)
      end
    end
  end
end
redis.call('del', 'available_ips')
redis.call('del', 'available_resources')
redis.call('del', 'used_ips')

local used_ports = redis.call('lrange', 'used_ports', 0, -1)
local used_length = #used_ports
for j = 1, used_length do
  local new_length = #resources
  for i = 1, new_length do
    if resources[i] then
      if resources[i].port == tonumber(used_ports[j]) then
        table.insert(used_resources, resources[i])
        table.remove(resources, i)
      end
    end
  end
end
redis.call('del', 'available_ports')
redis.call('del', 'used_ports')

for index, res in ipairs(resources) do
  resources[index] = cjson.encode(res)
end

for index, res in ipairs(used_resources) do
  used_resources[index] = cjson.encode(res)
end

for _,v in ipairs(resources) do
  redis.call('rpush', 'available_resources', v)
end

for _,v in ipairs(used_resources) do
  redis.call('rpush', 'used_resources', v)
end
EOF
)

redis-cli -p $redis_port eval "$luascript" 0