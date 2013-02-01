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
  ip = box['ip']
  box_path = "#{lxc_root}/#{name}"
  box_delta_path = "#{box_path}_delta"
  new_container_name = "#{name}-#{box['id']}"
  new_box_path = "#{lxc_root}/#{new_container_name}"
  new_box_delta_path = "#{new_box_path}_delta"

  redis.hset "aio:boxes", new_container_name, box_json

  if File.exists?("#{box_path}/config")
    puts "stop the running box: #{name}"
    `lxc-stop -n #{name}`
    `while nc -z #{ip} 22 ; do sleep 0.5; done`

    puts "rename lxc config"
    `sed -i "s/#{name}/#{new_container_name}/g" #{box_path}/config`

    puts "rename host name"
    `echo "#{new_container_name}" > #{box_path}/rootfs/etc/hostname`

    puts "change xfs-quota"
    `xfs_quota -x -c "limit -p bhard=0 #{name}" ${lxc_root}`

    puts "remove old entries from /etc/projects and /etc/projid"
    `sed -i "/#{name}_delta\\/rootfs\\/home\\/action/d" /etc/projects`
    `sed -i "/#{name}:/d" /etc/projid`

    # unmount the box
    if File.read('/proc/mounts').include?(box_path)
      puts "unmount: #{box_path}"
      `umount #{box_path}`
    end

    puts "move the old lxc-container to the new location"
    `mv #{box_path} #{new_box_path}`
    `mv #{box_delta_path} #{new_box_delta_path}`

    puts "remove the old redis setting"
    redis.hdel 'aio:boxes', box_name

    puts "Remount the container"
    mount_options = "rw,upperdir=#{new_box_delta_path},lowerdir=#{container_template_path}"
    `mount -n -t overlayfs -o #{mount_options} none #{new_box_path}`

    puts "add new entries of into /etc/projects and /etc/projid"
    `echo "#{box['id']}:#{new_box_delta_path}/rootfs/home/action" >> /etc/projects`
    `echo "#{new_container_name}:#{box['id']}" >> /etc/projid`

    puts "setting xfs quota"
    `xfs_quota -x -c "project -s #{new_container_name}" #{lxc_root}`
    `xfs_quota -x -c "limit -p bhard=#{box['diskSpace']} #{new_container_name}" #{lxc_root}`

    puts "start the container again"
    `lxc-start -n #{new_container_name} -d`
    puts "LXC_STARTED #{new_container_name}, going to nc #{ip}"
    `while ! nc -z #{ip} 22 ; do sleep 0.5; done`
    puts "Finished waiting for #{ip}"
  end
end
