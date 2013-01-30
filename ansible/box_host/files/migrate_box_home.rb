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

runtimes_map = {
  'ruby_container_template' => 'ruby_template',
  'python_container_template' => 'python_template',
  'nodejs_container_template' => 'nodejs_template',
  'golang_container_template' => 'golang_template',
}

all_box_ids.each do |box_id|
  box_json = redis.hget("aio:boxes", box_id)
  box = JSON.parse(box_json)

  name = box['name']
  ip = box['ip']
  new_template = runtimes_map[box['containerTemplate']]
  current_template_path = "/var/lib/lxc/#{box['containerTemplate']}"
  box_path = "#{lxc_root}/#{name}"
  box_delta_path = "#{box_path}_delta"

  # if config exists and the box has a newer template
  if File.exists?("#{box_path}/config") && new_template
    mount_options = "rw,upperdir=#{box_delta_path},lowerdir=#{container_template_path}"
    fstab_config = "none #{box_path} overlayfs #{mount_options} 0 0"

    puts "stop the running box: #{name}"
    `lxc-stop -n #{name}`
    `lxc-wait -n #{name} -s STOPPED`

    if File.read('/proc/mounts').include?(box_path)
      puts "unmount: #{box_path}"
      `umount #{box_path}`
    end

    puts "Migrating home dir"
    `rsync -aupzH #{current_template_path}/rootfs/home/action #{box_delta_path}/rootfs/home`

    puts "Remove /etc/fstab config"
    `sed -i "/#{quoted_lxc_root}#{name}\b/d" /etc/fstab`

    puts "Moving base to base_container_template"
    `mount -n -t overlayfs -o #{mount_options} none #{box_path}`
    `echo "#{fstab_config}" >> /etc/fstab`

    puts "change containerTemplate redis settings to #{new_template}"
    box['containerTemplate'] = new_template
    redis.hset "aio:boxes", box_id, JSON.generate(box)

    # start the box
    `lxc-start -n #{name} -d`
    puts "LXC_STARTED #{name}, going to nc #{ip}"
    `while ! nc -z #{ip} 22 ; do sleep 0.5; done`
    puts "Finished waiting for #{ip}"
  else
    puts "#{name} is not required for migration"
  end
end
