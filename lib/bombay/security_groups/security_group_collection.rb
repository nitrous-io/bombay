module Bombay
  class SecurityGroupCollection
    attr_accessor :region

    def initialize(region)
      self.region = region
      @security_groups = Set.new
    end

    def add(group)
      @security_groups.add group
    end

    def provision
      @security_groups.each { |sg| sg.provision }
    end

    def size
      @security_groups.size
    end

    def to_a
      @security_groups.to_a
    end

    def self.parse(region)
      collection = self.new(region)
      security_groups_yml = YAML.load(File.read(File.join(Bombay::ROOT, 'config', 'security_groups.yml')))

      security_groups_yml.each do |name, lines|
        security_group = Bombay::SecurityGroup.new(name, region)
        lines.each { |l| security_group.add_rule Bombay::SecurityRule.parse(l) }
        collection.add security_group
      end

      collection
    end
  end
end

