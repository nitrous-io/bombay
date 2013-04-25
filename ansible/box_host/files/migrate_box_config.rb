#!/usr/bin/env ruby
require 'rubygems'
require 'redis'
require 'json'

redis_port = ARGV.first
lxc_root = "/var/lib/lxc"
quoted_lxc_root = '\/var\/lib\/lxc\/'
container_template_path = "#{lxc_root}/base_container_template"

redis = Redis.new(:host => '127.0.0.1', :port => redis_port)

all_box_ids = redis.hkeys('aio:boxes')

all_box_ids.each do |box_id|
  config_template = <<-eos
lxc.cap.drop = audit_control audit_write
lxc.cap.drop = mac_admin mac_override
lxc.cap.drop = mknod setfcap setpcap
lxc.cap.drop = sys_boot sys_module sys_nice sys_pacct sys_rawio sys_resource
lxc.cap.drop = sys_time sys_tty_config
lxc.cap.drop = sys_admin

lxc.mount.entry = /sys/fs/fuse/connections /sys/fs/fuse/connections fusectl optional 0 0
lxc.mount.entry = /sys/kernel/debug /sys/kernel/debug debugfs optional 0 0
lxc.mount.entry = /sys/kernel/security /var/lib/lxc/#{box_id}/rootfs/sys/kernel/security securityfs optional 0 0
lxc.mount.entry = /run /var/lib/lxc/#{box_id}/rootfs/run tmpfs noexec,nosuid,size=10%,mode=0755  0 0
  eos

  box_json = redis.hget("aio:boxes", box_id)
  box = JSON.parse(box_json)

  ip = box['ip']
  box_path = "#{lxc_root}/#{box_id}"
  config_path = "#{box_path}/config"

  # only perform the changes when config file exists
  if File.exists?(config_path)
    puts "Remove lxc.cap.drop config for #{box_id}"
    `sed -i "/lxc.cap.drop/d" #{config_path}`
    puts "Remove lxc.mount.entry config"
    `sed -i "/lxc.mount.entry/d" #{config_path}`

    puts "append new config for #{box_id}"
    File.open(config_path, 'a') do |file|
      file << config_template
    end
  else
    puts "#{box_id} is not required for migration"
  end
end
