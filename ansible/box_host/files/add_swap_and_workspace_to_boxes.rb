#!/usr/bin/env ruby
require 'rubygems'
require 'redis'
require 'json'

redis_port = ARGV.first
lxc_root = "/var/lib/lxc"
quoted_lxc_root = '\/var\/lib\/lxc\/'
container_template_path = "#{lxc_root}/base_container_template"

redis = Redis.new(:host => '127.0.0.1', :port => redis_port)

all_box_names = redis.hkeys('aio:boxes')

all_box_names.each do |box_name|
  box_json = redis.hget("aio:boxes", box_name)
  box = JSON.parse box_json

  name = box['name']
  id = box['id']
  uid = 15000 + id.to_i
  gid = 15000 + id.to_i

  container_name = "#{name}-#{id}"
  box_path = "#{lxc_root}/#{container_name}"

  if File.exists?("#{box_path}/config")
    puts "Removing existing lines"
    `sed -i "/lxc.cgroup.memory.limit_in_bytes/d" #{box_path}/config`
    `sed -i "/lxc.cgroup.memory.memsw.limit_in_bytes/d" #{box_path}/config`

    total_memory_in_bytes = (768 * 1024 * 1024)
    puts "Setting memory to #{total_memory_in_bytes}"

    `echo "lxc.cgroup.memory.limit_in_bytes = 256M" >> #{box_path}/config`
    `echo "lxc.cgroup.memory.memsw.limit_in_bytes = 768M" >> #{box_path}/config`

    `echo #{total_memory_in_bytes} > /sys/fs/cgroup/memory/lxc/#{container_name}/memory.memsw.limit_in_bytes`
    puts "Setting memory to #{total_memory_in_bytes}"

    puts "Adding action directory"
    `mkdir -p #{box_path}/config/rootfs/home/action/workspace`
    `chroot #{box_path}/rootfs chown -R #{uid}:#{gid} /home/action/workspace`

    puts "Done with #{container_name}"
  end
end
