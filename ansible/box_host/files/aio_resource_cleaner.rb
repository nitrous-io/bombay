require 'rubygems'
require 'redis'
require 'json'

redis = Redis.new(host: '127.0.0.1', port: 65000)

available_resources = redis.lrange('available_resources', 0, -1)
used_resources = redis.lrange('used_resources', 0, -1)

puts "Available Resources: #{available_resources.length}"
puts "Used Resources: #{used_resources.length}"

redis.del('aio:available_resources')
redis.del('aio:used_resources')

available_resources.each do |json_resource|
  resource = JSON.parse(json_resource)
  ip = resource.delete('ip')

  guessed_gateway = ip.sub(/\.\d+$/, '.1')
  subnet = ip.split('.')[2]
  suffix = (subnet == '254' ? '' : "-#{subnet}")
  guessed_interface = "br-lxc#{suffix}"

  if guessed_gateway != resource['gateway'] || guessed_interface != resource['interface']
    puts "Guessed Gateway - #{guessed_gateway} Gateway - #{resource['gateway']} | Guessed Interface: #{guessed_interface} Interface - #{resource['interface']}"
  end

  redis.rpush('aio:available_resources', ip)
  redis.hmset("aio:nwr:#{ip}", *resource.to_a)
end

used_resources.each do |json_resource|
  resource = JSON.parse(json_resource)
  ip = resource.delete('ip')

  guessed_gateway = ip.sub(/\.\d+$/, '.1')
  subnet = ip.split('.')[2]
  suffix = (subnet == '254' ? '' : "-#{subnet}")
  guessed_interface = "br-lxc#{suffix}"

  if guessed_gateway != resource['gateway'] || guessed_interface != resource['interface']
    puts "Guessed Gateway - #{guessed_gateway} Gateway - #{resource['gateway']} | Guessed Interface: #{guessed_interface} Interface - #{resource['interface']}"
  end

  redis.rpush('aio:used_resources', ip)
  redis.hmset("aio:nwr:#{ip}", *resource.to_a)
end

puts "Available Resources Set Correctly: #{redis.llen('available_resources') == redis.llen('aio:available_resources')}"
puts "Used Resources Set Correctly: #{redis.llen('used_resources') == redis.llen('aio:used_resources')}"

