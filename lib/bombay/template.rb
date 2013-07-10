module Bombay
  class Template
    attr_accessor :name, :playbook_name, :lxc_container_path, :home_path

    TEMPLATES = {
      "golang_template" => "builder_template_golang",
      "ruby_template" => "builder_template_ruby",
      "nodejs_template" => "builder_template_nodejs",
      "python_template" => "builder_template_python",
    }

    def initialize(name, playbook_name)
      self.name = name
      self.playbook_name = playbook_name
      self.lxc_container_path = "/var/lib/lxc/#{TEMPLATES[playbook_name]}_delta"
      self.home_path = "#{self.lxc_container_path}/rootfs/home/action"
    end

    def build!
      path = File.join(Bombay::ROOT, "ansible", name, "plays", "#{self.playbook_name}.yml")

      ENV['ANSIBLE_CONFIG'] = "#{Bombay::ROOT}/config/ansible.container.cfg"
      system "ansible-playbook #{Bombay::ROOT}/ansible/#{self.name}/plays/#{self.playbook_name}.yml " +
             "-i #{Bombay::ROOT}/config/hosts.containers " +
             "--private-key=#{Dir.home}/.ansible/bombay"
    end

    def deploy!
      raise ConfigFileMissingError if !File.exists?(self.lxc_container_path)
      version = Time.now.to_i
      packaged_container_name = "#{self.name}_#{version}.tar.gz"

      delete_from_container = [
        ".ssh",
        ".ansible",
        ".cache",
        ".bash_history",
      ]
      delete_from_container.each { |p| system "sudo rm -rf #{self.home_path}/#{p}" }

      system "sudo bash -c 'echo \"#{self.name}: #{version}\" > #{self.home_path}/.VERSION'"
      system "cd /var/lib/lxc && sudo tar -C #{self.home_path} -czpvf #{packaged_container_name} ."
      system "s3cmd put /var/lib/lxc/#{packaged_container_name} s3://bombay-apse.action.io/#{packaged_container_name}"
      system "sudo rm -rf /var/lib/lxc/#{packaged_container_name}*"

      puts "File is available in s3://bombay-apse.action.io/#{packaged_container_name}"
    end
  end
end
