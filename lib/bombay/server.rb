require 'yaml'
require 'erb'

module Bombay
  class Server
    attr_accessor :hostname, :role, :region, :size, :ip, :ami, :block_devices, :host_vars

    SSH_PORT = 65100

    def initialize(opts = {})
      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def exists?
      find_instance != nil
    end

    def host_vars
      output = []
      @host_vars.each { |k, v| output << "#{k}=\"#{v}\"" }

      output.join(' ')
    end

    def inspect
      "#Bombay::Server #{self.hostname}: #{self.region}: #{self.size} | vars=> #{self.host_vars.inspect}"
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

    def self.build!(servers, region, environment)
      keypair_file_path = File.join(Dir.home, '.ec2', "#{region}-keypair.pem")
      # Used by the ERB binding
      ssh_port = Bombay::Server::SSH_PORT

      role = servers.first.role
      timestamp = Time.now.to_i

      ansible_hosts_file = File.join("/tmp", "#{role}-#{timestamp}.cfg")
      ansible_config_file = File.join("/tmp", "#{role}-config-#{timestamp}.cfg")

      ansible_server_template_path = File.join(File.dirname(__FILE__),
                                               "templates",
                                               "ansible.server.config_template.erb")

      ansible_config = ERB.new(File.read(ansible_server_template_path))

      if !File.exists?(keypair_file_path)
        raise Bombay::PrivateKeyDoesNotExistError, keypair_file_path
      end

      hosts_file_content = build_hosts_file_content(role, servers, region, environment)

      File.open(ansible_hosts_file, 'w') { |f| f.puts(hosts_file_content) }
      File.open(ansible_config_file, 'w') { |f| f.puts(ansible_config.result(binding)) }

      ENV['ANSIBLE_CONFIG'] = ansible_config_file

      setup_vars_files!(role, environment)

      command = "cd #{Bombay::ROOT}/ansible && " +
        "ansible-playbook servers/#{role}/plays/main.yml " +
        "-e \"env=#{environment} region=#{region}\" " +
        "-i #{ansible_hosts_file} " +
        "--private-key=#{keypair_file_path}"

      system command

      #FileUtils.rm_rf(ansible_hosts_file)
      #FileUtils.rm_rf(ansible_config_file)
    end

    def self.build_hosts_file_content(role, servers, region, environment)
      "[#{role}]\n#{servers.map { |s| "#{s.hostname} #{s.host_vars}" }.join("\n")}"
    end

    def self.initialize_role(role)
      config_file_path = File.join(Bombay::ROOT, 'ansible', 'servers', role, 'config.yml')
      raise ConfigFileMissingError unless File.exists?(config_file_path)
      region_to_server_map =  {}
      yaml = YAML.load(File.read(config_file_path))

      regions_config = yaml['regions']

      regions_config.each do |region_config|
        envs = {}

        region_config['environments'].each do |env, env_config|
          host_vars = assemble_host_vars_from_hash(yaml['host_vars'] || {})
          host_vars.merge!(assemble_host_vars_from_hash(env_config['host_vars'] || {}))

          env_config['hosts'].each do |server|
            host_vars.merge!(assemble_host_vars_from_hash(server['host_vars'] || {}))

            server = Bombay::Server.new(hostname: server['hostname'],
                                        size: server['size'],
                                        ami: server['ami'],
                                        role: role,
                                        region: region_config['region'],
                                        block_devices: server['block_devices'],
                                        host_vars: host_vars)
            if envs[env].nil?
              envs[env] = [server]
            else
              envs[env] += server
            end
          end
        end

        region_to_server_map[region_config['region']] = envs
      end

      region_to_server_map
    end

    def self.setup_vars_files!(role, environment)
      config_yml = YAML.load(File.read(File.join(Bombay::ROOT, 'ansible', 'servers', role, 'config.yml')))

      var_files = config_yml['var_files'] || {}

      var_files.each do |name, var_body|
        if var_body['context'] == 'global'
          var_file_name = File.join(Bombay::ROOT, 'ansible', 'vars_files', "#{name}.yml")
        elsif var_body['context'] == 'environment'
          var_file_name = File.join(Bombay::ROOT, 'ansible', 'vars_files', "#{name}.#{environment}.yml")
        elsif var_body['context'] == 'region'
          var_file_name = File.join(Bombay::ROOT, 'ansible', 'vars_files', "#{name}.#{region}.yml")
        end

        if !File.exists?(var_file_name)
          puts "Please enter these values to be placed in the var file var_files/#{name}.#{environment}.yml:"
          output_hash = {}

          var_body['vars'].each do |var|
            prompt = "#{var['prompt']}:"
            while output_hash[var['name']].blank?
              output_hash[var['name']] = (var['multiline'] ? ask_editor(prompt) : ask(prompt))
            end
          end

          File.open(var_file_name, 'w') { |f| f.puts(output_hash.to_yaml) }
        end
      end
    end

    protected
    def assign_ip_from_dns!
      dns = Fog::DNS.new(provider: 'AWS',
                         aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                         aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])

      root_domain = get_root_domain_from(self.hostname)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        raise Bombay::AwsDnsZoneMissingError
      else
        record = zone.records.select { |r| r.name == "#{self.hostname}." }.first

        if record
          cname = record.value.first
          cname_matcher = cname.match(/ec2-(\d+)-(\d+)-(\d+)-(\d+)\./)

          if cname_matcher && cname_matcher.size == 5
            self.ip = "#{cname_matcher[1]}.#{cname_matcher[2]}.#{cname_matcher[3]}.#{cname_matcher[4]}"
          else
            raise Bombay::AwsElasticIpError
          end
        end
      end
    end

    def create_dns_record!
      dns = Fog::DNS.new(provider: 'AWS',
                         aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                         aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'])

      root_domain = get_root_domain_from(self.hostname)
      zone = dns.zones.select { |z| z.domain == "#{root_domain}." }.first

      if zone.nil?
        raise Bombay::AwsDnsZoneMissingError
      else
        domain_name = "ec2-#{self.ip.gsub(/\./, '-')}.#{self.region}.compute.amazonaws.com"

        zone.records.create(value: domain_name,
                            name: self.hostname,
                            type: 'CNAME')

        # Box Hosts need wildcard domain too because we allow
        # users to access individual boxes
        if root_domain == 'actionbox.io'
          zone.records.create(value: domain_name,
                              name: "*.#{self.hostname}",
                              type: 'CNAME')
        end

        puts "Created DNS record for #{self.hostname}"
      end
    end

    def create_elastic_ip!
      compute = Fog::Compute.new(provider: 'AWS',
                                 aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                 aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                 region: region)
      result = compute.allocate_address
      self.ip = result.body['publicIp']
    end

    def create_instance!
      compute = Fog::Compute.new(provider: 'AWS',
                                 aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                 aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                 region: self.region)

      if compute.security_groups.get(self.role).nil?
        raise Bombay::AwsSecurityGroupMissingError
      end

      server_def = {
        image_id: self.ami,
        flavor_id: self.size,
        key_name: "#{self.region}-keypair",
        availability_zone: "#{self.region}a",
        groups: ["#{self.role}"],
        tags: {
          ip: self.ip,
          Name: self.hostname,
          Purpose: self.role
        }
      }

      if self.block_devices && !self.block_devices.empty?
        server_def[:block_device_mapping] = self.block_devices
      end

      server = compute.servers.create(server_def)

      if server
        puts "Waiting for #{self.hostname} to boot up"
        server.wait_for { print "."; ready? }
        print "\n"
        compute.associate_address(server.id, self.ip)
        record_host_config(server)
        print "Waiting for sshd"
        print(".") until tcp_test_ssh(server.dns_name, SSH_PORT) {
          puts("Done")
        }
      end

      server
    end

    def record_host_config(server)
      host_name = server.tags && server.tags["Name"] ? server.tags['Name'] : server.dns_name

      if server.groups && server.groups.include?('nagios')
        file_name = 'nagios-server.yml'
        server_config = {
          'nagios_server_name' => host_name,
          'nagios_server_ip' => server.private_ip_address
        }
      else
        file_name = 'nagios-host.yml'
        server_config = {
          'nagios_host_name' => host_name,
          'nagios_host_ip' => server.private_ip_address
        }
      end

      current_file_dir = File.expand_path(File.dirname(__FILE__))
      file_path = File.join(current_file_dir, '..', '..', 'ansible', 'config', file_name)

      File.open(file_path, 'w') do |file|
        file.write YAML.dump(server_config)
      end
    end

    def find_instance
      compute = Fog::Compute.new(provider: 'AWS',
                                 aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
                                 aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
                                 region: self.region)
      servers = compute.servers.all('tag:Name' => self.hostname)
      servers.select { |s| s.state == 'running' }.first
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

    def self.set_config_vars_for(root_directory, file, environment, region, vars)
      file_name = File.join(root_directory, "#{file}.#{region}.#{environment}")

      if !File.exists?(file_name)
        config_info = {}

        vars.each do |var|
          prompt = var['prompt']
          prompt = "#{prompt} (Default: #{var['default']})" if var['default']
          prompt = "#{prompt}:"

          while config_info[var['name']].blank?
            config_info[var['name']] = (var['multiline'] ? ask_editor(prompt) : ask(prompt))
            if config_info[var['name']].blank?
              config_info[var['name']] = var['default']
            end
          end
        end

        config_template = ERB.new(File.read(File.join(root_directory, "#{file}.config.erb")))

        File.open(file_name, 'w') do |f|
          f.puts(config_template.result(binding))
        end
      end
    end

    def self.assemble_host_vars_from_hash(host_vars_from_yaml)
      host_vars = {}

      host_vars_from_yaml.each do |namespace, vars_array|
        vars_array.each do |var|
          host_vars["#{namespace}_#{var['name']}"] = var['value']
        end
      end

      host_vars
    end
  end
end
