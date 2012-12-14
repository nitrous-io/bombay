module Bombay
  class SecurityGroup
    include Bombay::AWS

    attr_accessor :name, :region

    def initialize(name, region)
      self.name = name
      self.region = region
      @rules = Set.new
    end

    def add_rule(rule)
      @rules.add rule
    end

    def eql?(group)
      self.name.eql?(group.name) &&
      self.region.eql?(group.region) &&
      self.rules.eql?(group.rules)
    end

    def hash
      [self.name, self.region, self.rules].hash
    end

    def provision
      security_group = compute.security_groups.get(self.name) ||
                       compute.security_groups.create(name: self.name,
                                                      description: self.name).reload
      security_group.sync(@rules)
    end

    def rules
      @rules.to_a
    end
  end
end
