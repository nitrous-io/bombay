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
  box_json = redis.hget("aio:boxes", box_id)
  box = JSON.parse(box_json)

  if box['containerTemplate']  == 'python_template'
    puts "Fixing #{box_id}"
    id = box['id']
    uid = 15000 + id.to_i
    gid = 15000 + id.to_i

    box_path = "#{lxc_root}/#{box_id}"
    box_delta_path = "#{box_path}_delta"

    pip_conf = "#{box_delta_path}/rootfs/home/action/.pip/pip.conf"

    if File.exists?(pip_conf)
      puts "Found existing .pip. Skipping"
    else
      puts "creating .pip if possible"
      `mkdir -p #{box_path}/rootfs/home/action/.pip`

      puts "adding pip.conf"
      `touch #{box_path}/rootfs/home/action/.pip/pip.conf`
      `echo "[global]" >> #{box_path}/rootfs/home/action/.pip/pip.conf`
      `echo "user = true" >> #{box_path}/rootfs/home/action/.pip/pip.conf`

      puts "setting permissions of .pip folder"
      `chroot #{box_path}/rootfs chown -R #{uid}:#{gid} /home/action/.pip`
    end
  end
end
