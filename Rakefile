require "bundler/gem_tasks"

namespace :generate do
  task :server, :name do |t, args|
    if args[:name].nil? || args[:name].length == 0
      puts "Usage: rake generate:server[name]"
    else
      sh "./generators/generate_server_template.sh #{args[:name]}"
      puts "** Done **"
    end
  end

  task :container, :name, :ip, :gateway do |t, args|
    name, ip, gateway = args[:name], args[:ip], args[:gateway]

    if name.nil? || name.length == 0 ||
       ip.nil? || ip.length == 0 ||
       gateway.nil? || gateway.length == 0
      puts "Usage: rake generate:container[name,ip,gateway]"
    else
      sh "./generators/generate_container_template.sh #{name} #{ip} #{gateway}"
      puts "** Done **"
    end
  end
end
