require 'rubygems'
require 'redis'
require 'json'

file = ARGV[0]
redis_host = ARGV[1] || '127.0.0.1'
redis_port = ARGV[2] || 65000

lines = File.read(file).split("\n")

redis = Redis.new(host: redis_host, port: redis_port)

def number_of_occurrences_in_fstab(name)
  contents = File.read("/etc/fstab")
  contents.scan(/\/var\/lib\/lxc\/#{name}_delta\b/).count
end

def number_of_occurrences_in_proc_mounts(name)
  contents = File.read("/proc/mounts")
  contents.scan(/\/var\/lib\/lxc\/#{name}_delta\b/).count
end

def number_of_occurrences_in_etc_projid(id, name)
  contents = File.read("/etc/projid")
  contents.scan(/#{name}:#{id}$/).count
end

def number_of_occurrences_in_etc_projects(id, name)
  contents = File.read("/etc/projects")
  contents.scan(/#{id}:\/var\/lib\/lxc\/#{name}_delta\/rootfs\/home\/action$/).count
end

lines.each do |line|
  id, name, state = line.split('|')

  if state == 'stopped'
    box_json = redis.hget('aio:boxes', name)
    box_info = JSON.parse(box_json)
    box_info['containerState'] = 'stopped'
    #p "Stopped: #{box_info}"
    redis.hset('aio:boxes', name, box_info.to_json)
    if (fstab = number_of_occurrences_in_fstab(name)) != 0
      puts "Occurs in /etc/fstab #{fstab} times when it should be zero: #{name}, #{state}"
    end

    if (proc_mounts = number_of_occurrences_in_proc_mounts(name)) != 0
      puts "Occurs in /proc/mounts #{proc_mounts} times when it should be zero: #{name}, #{state}"
    end

    if (etc_projects = number_of_occurrences_in_etc_projects(id, name)) != 0
      puts "Occurs in /etc/projects #{etc_projects} times when it should be zero: #{id}, #{name}, #{state}"
    end

    if (etc_projid = number_of_occurrences_in_etc_projid(id, name)) != 0
      puts "Occurs in /etc/projid #{etc_projid} times when it should be zero: #{id}, #{name}, #{state}"
    end
  elsif state == 'running'
    box_json = redis.hget('aio:boxes', name)
    box_info = JSON.parse(box_json)
    box_info['containerState'] = 'running'
    #p "Running: #{box_info}"
    redis.hset('aio:boxes', name, box_info.to_json)

    if (fstab = number_of_occurrences_in_fstab(name)) != 1
      puts "Occurs in /etc/fstab #{fstab} times when it should be one: #{name}, #{state}"
    end

    if (proc_mounts = number_of_occurrences_in_proc_mounts(name)) != 1
      puts "Occurs in /proc/mounts #{proc_mounts} times when it should be one: #{name}, #{state}"
    end

    if (etc_projects = number_of_occurrences_in_etc_projects(id, name)) != 1
      puts "Occurs in /etc/projects #{etc_projects} times when it should be one: #{id}, #{name}, #{state}"
    end

    if (etc_projid = number_of_occurrences_in_etc_projid(id, name)) != 1
      puts "Occurs in /etc/projid #{etc_projid} times when it should be one: #{id}, #{name}, #{state}"
    end
  elsif state == 'terminated'
    box_json = redis.hget('aio:boxes', name)
    unless box_json.nil?
      puts "Terminated Box exists in Redis #{name}"
    end

    if File.exists? "/var/lib/lxc/#{name}"
      puts "Error: This box should not exist #{name}"
    end

    if (fstab = number_of_occurrences_in_fstab(name)) != 0
      puts "Occurs in /etc/fstab #{fstab} times when it should be zero: #{name}, #{state}"
    end

    if (proc_mounts = number_of_occurrences_in_proc_mounts(name)) != 0
      puts "Occurs in /proc/mounts #{proc_mounts} times when it should be zero: #{name}, #{state}"
    end

    if (etc_projects = number_of_occurrences_in_etc_projects(id, name)) != 0
      puts "Occurs in /etc/projects #{etc_projects} times when it should be zero: #{id}, #{name}, #{state}"
    end

    if (etc_projid = number_of_occurrences_in_etc_projid(id, name)) != 0
      puts "Occurs in /etc/projid #{etc_projid} times when it should be zero: #{id}, #{name}, #{state}"
    end
  end
end
