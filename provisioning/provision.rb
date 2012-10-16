#!/usr/bin/env ruby

require 'inifile'
require 'fog'
require 'domainatrix'

$env = ARGV[0]
$action_role = ARGV[1]
$aws_region = ARGV[2]
$aws_size = ARGV[3]

module ActionIO
  class SecurityRule
    attr_accessor :port_range, :protocol, :source

    def initialize(opts = {})
      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def inspect
      "#{self.port_range}|#{self.protocol}|#{self.source}"
    end

    def port_range
      start_port, end_port = @port_range.split("-")
      end_port = start_port if end_port.nil?

      Range.new(start_port, end_port)
    end

    def is_ip?
      # Check if there are 4 octets, otherwise
      # this is a security group
      self.source.split(".").length == 4
    end
  end

  class SecurityGroup
    attr_accessor :name, :region, :rules

    def initialize(name, region)
      self.name = name
      self.region = region
      self.rules = []
    end

    def inspect
      "##{self.name}: #{self.rules.inspect}"
    end

    def create!
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: self.region
                )

      security_group = compute.security_groups.get(self.name)

      if security_group.nil?
        # Create the group
        security_group = compute.security_groups.create(name: self.name,
                                                        description: self.name)
        security_group.reload
      end

      # Update the rules
      # TODO: If the rule doesn't exist in ActionIO::SecurityGroup#rules,
      # then you should delete it from the AWS Security Group
      self.rules.each do |rule|
        next if rule_exists_in_security_group?(rule, security_group)

        if rule.is_ip?
          security_group.authorize_port_range(rule.port_range,
                                              cidr_ip: rule.source,
                                              ip_protocol: rule.protocol)
        else
          security_group.authorize_port_range(rule.port_range,
                                              group: rule.source,
                                              owner_id: security_group.owner_id,
                                              ip_protocol: rule.protocol)
        end
      end
    end

    def rule_exists_in_security_group?(rule, sg)
      sg.ip_permissions.select do |permission|
        ports_condition = (permission['fromPort'].to_i == rule.port_range.begin.to_i &&
                           permission['toPort'].to_i == rule.port_range.end.to_i)
        protocol_condition = (permission['ipProtocol'] == rule.protocol)
        ips = permission['ipRanges'].map { |i| i['cidrIp'] }
        groups = permission['groups'].map { |g| g['groupName'] }

        sources = rule.source.split(',')
        ip_condition = (sources - ips).size == 0
        group_condition = (sources - groups).size == 0

        ports_condition && protocol_condition && (ip_condition || group_condition)
      end.count > 0
    end

    def self.get_all_for(region)
      ini_file = "config/security_groups.cfg"
      security_groups = {}

      parsed_ini = IniFile.load(ini_file)

      if parsed_ini
        parsed_ini.each do |name|
          if (security_group = security_groups[name]).nil?
            security_group = self.new(name, region)
            security_groups[name] = security_group
          end

          values = parsed_ini[name]['values']
          values.each do |line|
            port_range, protocol, source = line.split(/\s+/)
            security_group.rules << ActionIO::SecurityRule.new(port_range: port_range,
                                                               protocol: protocol,
                                                               source: source,
                                                               name: name)
          end
        end
      else
        puts "Could not find #{ini_file}"
        exit(1)
      end

      if security_groups.empty?
        puts "You haven't defined any security groups in #{ini_file}"
        exit(1)
      end

      security_groups.values
    end
  end
end

module ActionIO
  class Server
    attr_accessor  :name, :region, :size, :ip, :role

    def initialize(opts = {})
      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def self.get_all_for(env, role, region, size)
      ini_file = "config/hosts.servers.#{env}"
      servers = []

      parsed_ini = IniFile.load(ini_file)

      if parsed_ini
        section = parsed_ini[role]
        if section
          server_domains = section['values']

          if server_domains.empty?
            puts "Could not find #{role} in #{ini_file}"
            exit(1)
          end

          server_domains.each { |d| p d; servers << self.new(name: d, region: region, size: size, role: role) }
        else
          puts "Could not find #{role} in #{ini_file}"
          exit(1)
        end
      else
        puts "Could not find #{ini_file}"
        exit(1)
      end

      servers
    end

    def inspect
      "#{self.name}: #{self.region}: #{self.size}"
    end

    def assign_ip_from_dns!
      dns = Fog::DNS.new(
              provider: 'AWS',
              aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
              aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
            )

      root_domain = get_root_domain_from(self.name)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        puts "Could not find #{root_domain} in Route53 records"
        exit(1)
      else
        record = zone.records.select { |r| r.name == "#{name}." }.first

        if record
          cname = record.value.first
          cname_matcher = cname.match(/ec2-(\d+)-(\d+)-(\d+)-(\d+)\./)

          if cname_matcher && cname_matcher.size == 5
            self.ip = "#{cname_matcher[1]}.#{cname_matcher[2]}.#{cname_matcher[3]}.#{cname_matcher[4]}"
          else
            puts "IP Not Found for #{name}"
          end
        else
          puts "IP Not Found for #{name}"
        end
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
      puts "Created IP #{result.body['publicIp']}"
      self.ip = result.body['publicIp']
    end

    def create_dns_record!
      dns = Fog::DNS.new(
              provider: 'AWS',
              aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
              aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
            )

      root_domain = get_root_domain_from(name)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        puts "Could not find #{root_domain} in Route53 records"
        exit(1)
      else
        domain_name = "ec2-#{self.ip.gsub(/\./, '-')}.#{self.region}.compute.amazonaws.com"

        result = zone.records.create(
          value: domain_name,
          name: self.name,
          type: 'CNAME'
        )

        # Box Hosts need wildcard domain too because we allow
        # users to access individual boxes
        if root_domain == 'actionbox.io'
          zone.records.create(
            value: domain_name,
            name: "*.#{self.name}",
            type: 'CNAME'
          )
        end

        puts "Created DNS record for #{self.name} -> #{result}"
      end
    end

    def find_instance
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: self.region
                )
      server = compute.servers.all('tag:Name' => self.name).first
      (server.nil? || server.state == 'terminated') ? nil : server
    end

    def create_instance!
      compute = Fog::Compute.new(
                  provider: 'AWS',
                  aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                  aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                  region: self.region
                )

      if compute.security_groups.get(self.role).nil?
        puts "Error: Security Group #{self.role} does not exist"
        exit(1)
      end

      server_def = {
        image_id:           choose_ami(self.region, self.role),
        flavor_id:          self.size,
        key_name:           "#{self.region}-keypair",
        availability_zone:  "#{self.region}a",
        groups:             ["#{self.role}"],
        tags: {
          ip:       self.ip,
          Name:     self.name,
          Purpose:  self.role
        }
      }

      server = compute.servers.create(server_def)

      if server
        puts "Waiting for #{self.name} to boot up"
        server.wait_for { print "."; ready? }
        print "\n"
        compute.associate_address(server.id, self.ip)

        print "Waiting for sshd"
        print(".") until tcp_test_ssh(server.dns_name, 65100) {
          puts("Done")
        }
      end

      server
    end

    def provision!
      # Check if name exists in Route53
      assign_ip_from_dns!

      if self.ip.nil?
        create_elastic_ip! && create_dns_record!
      end

      # Check if AWS instance with that domain exists
      instance = find_instance
      instance = create_instance! if instance.nil?
    end

    protected
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

    def get_root_domain_from(name)
      parsed_domain = Domainatrix.parse(name)
      "#{parsed_domain.domain}.#{parsed_domain.public_suffix}"
    end

    protected
    def choose_ami(region, role)
      if role == 'box_host'
        case region
        when 'ap-southeast-1' then 'ami-96cc8cc4'
        else nil
        end
      else
        case region
        when 'ap-southeast-1' then 'ami-fac686a8'
        else nil
        end
      end
    end
  end
end

if ActionIO::Server::REGION_TO_VANILLA_AMI.has_key?($aws_region)
  ActionIO::SecurityGroup.get_all_for($aws_region).each { |sg| sg.create! }
  ActionIO::Server.get_all_for($env, $action_role, $aws_region, $aws_size).each { |server| server.provision! }
else
  puts "We do not support this region: #{$aws_region} right now"
  exit 1
end
