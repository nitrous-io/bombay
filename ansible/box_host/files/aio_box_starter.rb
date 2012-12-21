require 'rubygems'
require 'redis'
require 'json'

redis = Redis.new(host: '127.0.0.1', port: 65000)

all_box_ids = redis.hkeys('aio:boxes')

all_box_ids.each do |box_id|
  box_json = redis.hget("aio:boxes", box_id)
  box = JSON.parse(box_json)

  ip = box['ip']

  if File.exists?("/var/lib/lxc/#{box_id}/config")
    `lxc-start -n #{box_id} -d`
    puts "LXC_STARTED #{box_id}, going to nc #{ip}"
    `while ! nc -z #{ip} 22 ; do sleep 0.5; done`
    puts "Finished waiting for #{ip}"
  else
    puts "Could not find config file for #{box_id}"
  end
  
end
