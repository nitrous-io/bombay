module Bombay
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
