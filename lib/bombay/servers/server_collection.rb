module Bombay
  class ServerCollection
    include Commander::UI
    include Bombay::Ansibler

    attr_accessor :current_region, :environment
    attr_reader   :sensitive_vars, :regions, :role

    def initialize(role, sensitive_vars={})
      @role = role
      @servers, @regions = [], []
      @sensitive_vars = sensitive_vars || {}
    end

    def add(server)
      @servers.push server
    end

    def ansible_hosts
      running_servers = @servers.select do |s|
        s.cloud_state == 'running' &&
        s.region == current_region &&
        s.environment == environment
      end

      "[#{self.role}]\n#{running_servers.map { |s| "#{s.hostname} #{s.vars}" }.join("\n")}"
    end

    def build(playbook)
      keypair = File.join(Dir.home, '.ec2', "#{self.current_region}-keypair.pem")
      # Used by the ERB binding
      ssh_port = Bombay::Server::SSH_PORT

      ansible_server_template_path = File.join(File.expand_path(File.join(File.dirname(__FILE__), '/../')),
                                               "templates",
                                               "ansible.server.config_template.erb")

      ansible_config = ERB.new(File.read(ansible_server_template_path))

      playbook = if File.exists? File.join(Bombay::ROOT, 'ansible', self.role, 'plays', "#{playbook}.yml")
                   "#{self.role}/plays/#{playbook}.yml"
                 elsif File.exists? File.join(Bombay::ROOT, 'ansible', 'shared', 'plays', "#{playbook}.yml")
                   "shared/plays/#{playbook}.yml"
                 end

      run_playbook(playbook,
                   keypair,
                   ansible_hosts,
                   ansible_config.result(binding),
                   { env: environment, region: current_region, role: self.role })
    end

    def cache_sensitive_vars!
      @sensitive_vars.each do |name, var_body|
        var_file_name = case var_body['context']
        when 'environment'
          File.join(Bombay::ROOT, 'ansible', 'vars_files', "#{name}.#{environment}.yml")
        else
          File.join(Bombay::ROOT, 'ansible', 'vars_files', "#{name}.yml")
        end

        unless File.exists?(var_file_name)
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

    def provision
      regions = @servers.map(&:region).uniq.sort

      regions.each { |r| Bombay::SecurityGroupCollection.parse(r).provision }
      @servers.each { |s| s.provision }
    end

    def set_environment!
      environments = @servers.map(&:environment).uniq.sort
      picked_env = nil

      if environments.count > 1
        while environments.index(picked_env).nil?
          picked_env = ask "Pick a region from #{environments.join(',')}: "
        end
        @environment = picked_env
      else
        @environment = environments.first
      end
    end

    def set_regions!
      regions = @servers.map(&:region).uniq.sort
      picked_region = nil

      if regions.count > 1
        while regions.index(picked_region).nil?
          picked_region = ask "Pick a region from #{regions.join(',')} (or type 'all' to build in all regions): "
          if picked_region == 'all'
            @regions = regions
            return
          end
        end

        @regions.push picked_region
      else
        @regions.push regions.first
      end
    end

    def size; @servers.size; end

    def to_a; @servers; end

    def self.parse(role)
      config_file = File.join(Bombay::ROOT, "ansible", role, "config.yml")
      parsed_yaml = nil

      return nil if !File.exists? config_file

      begin
        parsed_yaml = YAML.load(File.read(config_file))
      rescue Psych::SyntaxError
        return nil
      end

      # Initialize a new server collection, and fill it up
      # with servers read from config.yml
      server_collection = self.new(role, parsed_yaml['sensitive_vars'])

      parsed_yaml['regions'].each do |region_config|
        region_config['environments'].each do |env, env_config|
          env_config['servers'].each do |server_config|
            server = Bombay::Server.new(hostname: server_config['hostname'],
                                        size: server_config['size'],
                                        ami: server_config['ami'],
                                        role: role,
                                        environment: env,
                                        region: region_config['region'])

            server.block_devices = Bombay::BlockDeviceCollection.new(server_config['block_devices'])

            # initialize with the vars which have global scope
            server.vars = Bombay::ServerVariables.new(parsed_yaml['server_vars'])
            # ...then scoped to the environment
            server.vars.merge!(env_config['server_vars'])
            # ...and finally specific to the host
            server.vars.merge!(server_config['server_vars'])

            server_collection.add server
          end
        end
      end

      server_collection
    end
  end
end
