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
end
