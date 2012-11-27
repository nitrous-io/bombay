module Bombay
  class Local
    attr_accessor :name, :playbook_name

    def initialize(name, playbook_name)
      self.name = name
      self.playbook_name = playbook_name
    end

    def build!
      if !File.exists?(File.join(Bombay::ROOT, "ansible", "local", name, "plays", "#{playbook_name}.yml"))
        raise Bombay::ConfigFileMissingError
      end

      system "ansible-playbook #{Bombay::ROOT}/ansible/local/#{self.name}/plays/#{playbook_name}.yml " +
             "-i #{Bombay::ROOT}/ansible/config/hosts.local"
    end
  end
end
