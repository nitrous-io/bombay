module Bombay
  class Local
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def build!
      if !File.exists?(File.join(Bombay::ROOT, "ansible", "local", name, "plays", "main.yml"))
        raise Bombay::ConfigFileMissingError
      end

      system "ansible-playbook #{Bombay::ROOT}/ansible/local/#{self.name}/plays/main.yml " +
             "-i #{Bombay::ROOT}/ansible/config/hosts.local"
    end
  end
end
