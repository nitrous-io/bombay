module Bombay
  class Server
    include Bombay::AWS
    include Commander::UI

    attr_accessor :hostname, :role, :region, :environment,
                  :size, :ami, :block_devices, :vars

    attr_reader   :ssh_port, :ip

    SSH_PORT = 65100

    def initialize(opts = {})
      load_credentials!

      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
      @ssh_port = SSH_PORT
      @cloud_instance = nil
    end

    def cloud_instance
      unless @cloud_instance
        @cloud_instance = compute.servers.all.select do |s|
          s.state != 'terminated' &&
          s.state != 'shutting-down' &&
          s.tags['Name'] == self.hostname
        end.first
      end

      @cloud_instance
    end

    def cloud_state
      cloud_instance.try(:state) || 'terminated'
    end

    def inspect
      "#Bombay::Server #{self.hostname}: #{self.region}: #{self.size} | vars=> #{self.vars.inspect}"
    end

    def provision
      if cloud_state == 'terminated'
        say "#{self.hostname} is terminated, provisioning now..."

        # Check if name exists in Route53
        assign_ip_from_dns!

        if @ip.nil?
          say "creating elastic ip and dns record..."
          create_elastic_ip! && create_dns_record!
          say "IP: #{@ip}"
        end

        create_instance
      end
    end

    protected
    def assign_ip_from_dns!
      if (zone = zone_from(self.hostname)).present?
        record = zone.records.get(self.hostname)

        if record
          cname = record.value.first
          return unless cname

          cname_matcher = cname.match(/ec2-(\d+)-(\d+)-(\d+)-(\d+)\./)

          if cname_matcher && cname_matcher.size == 5
            matched_ip = "#{cname_matcher[1]}.#{cname_matcher[2]}.#{cname_matcher[3]}.#{cname_matcher[4]}"
            # If the elastic IP does not exist, then @ip will be set to nil
            # and bombay will create a new elastic IP address
            @ip = compute.addresses.get(matched_ip).try(:public_ip)
          end
        end
      end
    end

    def create_dns_record!
      if (zone = zone_from(self.hostname)).present?
        domain_name = "ec2-#{self.ip.gsub(/\./, '-')}.#{self.region}.compute.amazonaws.com"
        # If the DNS record exists, that means that DNS entry exists
        # for an elastic IP which has been released
        if (record = zone.records.get(self.hostname))
          change_dns_value(record, domain_name)

          # If this is an actionbox.io URL, then update the DNS value there
          # as well
          if self.hostname =~ /actionbox\.io/
            if (record = zone.records.get("*.#{self.hostname}"))
              change_dns_value(record, domain_name)
            end
          end
        else
          record = zone.records.create(value: domain_name,
                                       name: self.hostname,
                                       type: 'CNAME')

          # Box Hosts need wildcard domain too because we allow
          # users to access individual boxes
          if self.hostname =~ /actionbox\.io$/
            zone.records.create(value: domain_name,
                                name: "*.#{self.hostname}",
                                type: 'CNAME')
          end
        end
      end
    end

    def create_elastic_ip!
      result = compute.allocate_address
      @ip = result.body['publicIp']
    end

    def create_instance
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

      if self.block_devices && !self.block_devices.to_a.empty?
        server_def[:block_device_mapping] = self.block_devices.to_hash
      end

      server = compute.servers.create(server_def)

      if server
        server.wait_for { print "."; ready? }
        say "#{self.hostname} provisioned, associating ip address..."
        compute.associate_address(server.id, self.ip)
        say "waiting for boot..."
        print(".") until tcp_test_ssh {
          puts("Done")
        }
      end

      server.reload
    end

    def change_dns_value(record, value)
      record.destroy
      record.value = value
      record.save
    end
  end
end
