module Bombay
  class SecurityRule
    attr_accessor :ports, :protocol, :source

    def initialize(opts = {})
      opts.each { |k,v| self.send("#{k}=", v) if self.respond_to?("#{k}=") }
    end

    def eql?(rule)
      self.port_range.eql?(rule.port_range) &&
      self.protocol.eql?(rule.protocol) &&
      self.source.eql?(rule.source)
    end

    def hash
      [self.port_range, self.protocol, self.source].hash
    end

    def is_source_ip?
      ip = IPAddress.parse(self.source) rescue nil
      ip.present?
    end

    def port_range
      start_port, end_port = @ports.split("-").map { |x| x.strip.to_i }
      end_port = start_port if end_port.nil?

      Range.new(start_port, end_port)
    end

    def source=(source)
      @source = source.to_s.split(',').map { |x| x.strip }.join(',')
    end

    def self.parse(line)
      ports, protocol, source = line.split(/\s+/)
      self.new(ports: ports, protocol: protocol, source: source)
    end
  end
end

