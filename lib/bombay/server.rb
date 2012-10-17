require 'yaml'
require 'erb'

module Bombay
  class Server
    attr_accessor  :hostname, :role, :region, :size, :ip, :ami

    SSH_PORT = 65100

    def initialize(opts = {})
      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def exists?
      find_instance != nil
    end

    def inspect
      "#Bombay::Server #{self.hostname}: #{self.region}: #{self.size}"
    end

    def provision!
      # Check if name exists in Route53
      assign_ip_from_dns!

      if self.ip.nil?
        create_elastic_ip! && create_dns_record!
      end

      # Check if AWS instance with that domain exists
      create_instance! unless exists?
    end

    def self.build!(servers, region)
      keypair_file_path = File.join(Dir.home, '.ec2', "#{region}-keypair.pem")
      ssh_port = Bombay::Server::SSH_PORT

      role = servers.first.role
      timestamp = Time.now.to_i

      ansible_hosts_file = File.join("/tmp", "#{role}-#{timestamp}.cfg")
      ansible_config_file = File.join("/tmp", "#{role}-config-#{timestamp}.cfg")

      ansible_server_template_path = File.join(File.dirname(__FILE__), "templates", "ansible.server.config_template.erb")
      ansible_config = ERB.new(File.read(ansible_server_template_path))

      if !File.exists?(keypair_file_path)
        raise Bombay::PrivateKeyDoesNotExistError, keypair_file_path
      end

      hosts_file_content = "[#{role}]\n#{servers.map(&:hostname).join("\n")}"
      File.open(ansible_hosts_file, 'w') { |f| f.puts(hosts_file_content) }
      File.open(ansible_config_file, 'w') { |f| f.puts(ansible_config.result(binding)) }

      ENV['ANSIBLE_CONFIG'] = ansible_config_file

      system "ansible-playbook #{Bombay::ROOT}/ansible/servers/#{role}/plays/main.yml " +
             "-i #{ansible_hosts_file} " +
             "--private-key=#{keypair_file_path}"

      FileUtils.rm_rf(ansible_hosts_file)
      FileUtils.rm_rf(ansible_config_file)
    end

    def self.initialize_role(role)
      config_file_path = File.join(Bombay::ROOT, 'ansible', 'servers', role, 'config.yml')
      raise ConfigFileMissingError unless File.exists?(config_file_path)
      region_to_server_map = {}

      regions_config = YAML.load(File.read(config_file_path))
      regions_config.each do |region_config|
        envs = {}

        region_config['environments'].each do |env, server|
          server = Bombay::Server.new(hostname: server['hostname'],
                                      size: server['size'],
                                      ami: server['ami'],
                                      role: role,
                                      region: region_config['region'])
          if envs[env].nil?
            envs[env] = [server]
          else
            envs[env] += server
          end
        end

        region_to_server_map[region_config['region']] = envs
      end

      region_to_server_map
    end

    protected

    def assign_ip_from_dns!
      dns = Fog::DNS.new(
              provider: 'AWS',
              aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
              aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
            )

      root_domain = get_root_domain_from(self.name)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        raise Bombay::DnsZoneMissingError
      else
        record = zone.records.select { |r| r.name == "#{name}." }.first

        if record
          cname = record.value.first
          cname_matcher = cname.match(/ec2-(\d+)-(\d+)-(\d+)-(\d+)\./)

          if cname_matcher && cname_matcher.size == 5
            self.ip = "#{cname_matcher[1]}.#{cname_matcher[2]}.#{cname_matcher[3]}.#{cname_matcher[4]}"
          else
            raise Bombay::ElasticIpError
          end
        else
          raise Bombay::ElasticIpError
        end
      end
    end

    def create_dns_record!
      dns = Fog::DNS.new(
              provider: 'AWS',
              aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
              aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
            )

      root_domain = get_root_domain_from(self.hostname)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        raise Bombay::DnsZoneMissingError
      else
        domain_name = "ec2-#{self.ip.gsub(/\./, '-')}.#{self.region}.compute.amazonaws.com"

        result = zone.records.create(
          value: domain_name,
          name: self.hostname,
          type: 'CNAME'
        )

        # Box Hosts need wildcard domain too because we allow
        # users to access individual boxes
        if root_domain == 'actionbox.io'
          zone.records.create(
            value: domain_name,
            name: "*.#{self.hostname}",
            type: 'CNAME'
          )
        end

        puts "Created DNS record for #{self.hostname} -> #{result}"
      end
    end

    def create_elastic_ip!
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: region
                )
      result = compute.allocate_address
      self.ip = result.body['publicIp']
    end

    def create_instance!
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: self.region
                )

      if compute.security_groups.get(self.role).nil?
        raise Bombay::SecurityGroupMissingError
      end

      server_def = {
        image_id:           self.ami,
        flavor_id:          self.size,
        key_name:           "#{self.region}-keypair",
        availability_zone:  "#{self.region}a",
        groups:             ["#{self.role}"],
        tags: {
          ip:       self.ip,
          Name:     self.hostname,
          Purpose:  self.role
        }
      }

      server = compute.servers.create(server_def)

      if server
        puts "Waiting for #{self.hostname} to boot up"
        server.wait_for { print "."; ready? }
        print "\n"
        compute.associate_address(server.id, self.ip)

        print "Waiting for sshd"
        print(".") until tcp_test_ssh(server.dns_name, SSH_PORT) {
          puts("Done")
        }
      end

      server
    end

    def find_instance
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: self.region
                )
      server = compute.servers.all('tag:Name' => self.hostname).first
      (server.nil? || server.state == 'terminated') ? nil : server
    end

    def get_root_domain_from(name)
      parsed_domain = Domainatrix.parse(name)
      "#{parsed_domain.domain}.#{parsed_domain.public_suffix}"
    end

    def tcp_test_ssh(hostname, ssh_port)
      tcp_socket = TCPSocket.new(hostname, ssh_port)
      readable = IO.select([tcp_socket], nil, nil, 5)
      if readable
        yield
        true
      else
        false
      end
    rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, IOError
      sleep 2
      false
    rescue Errno::EPERM, Errno::ETIMEDOUT
      false
    ensure
      tcp_socket && tcp_socket.close
    end
  end
end

