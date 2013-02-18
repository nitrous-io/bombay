module Bombay
  class Container
    attr_accessor :name, :playbook_name

    def initialize(name, playbook_name)
      self.name = name
      self.playbook_name = playbook_name
    end

    def build!
      path = File.join(Bombay::ROOT, "ansible", name, "plays", "#{self.playbook_name}.yml")

      ENV['ANSIBLE_CONFIG'] = "#{Bombay::ROOT}/config/ansible.container.cfg"
      system "ansible-playbook #{Bombay::ROOT}/ansible/#{self.name}/plays/#{self.playbook_name}.yml " +
             "-i #{Bombay::ROOT}/config/hosts.containers " +
             "--private-key=#{Dir.home}/.ansible/bombay"
    end

    def deploy!
      lxc_container_path = "/var/lib/lxc/#{self.name}"
      version = Time.now.to_i
      packaged_container_name = "#{self.name}_#{version}.tar.gz"

      delete_from_container = [
        "rootfs/home/action/.ssh",
        "rootfs/home/action/.ansible",
        "rootfs/home/action/.cache",
        "rootfs/home/action/.bash_history",
        "rootfs/home/action/.bashrc",
        "rootfs/home/action/*",
        "rootfs/var/log/*",
        "rootfs/var/cache/*"
      ]

      raise ConfigFileMissingError if !File.exists?(lxc_container_path)

      delete_from_container.each { |p| system "sudo rm -rf #{lxc_container_path}/#{p}" }

      system "sudo bash -c 'echo #{version} > #{lxc_container_path}/VERSION'"
      system "cd /var/lib/lxc && sudo tar cpvzf #{packaged_container_name} #{self.name}"
      system "s3cmd put /var/lib/lxc/#{packaged_container_name} s3://bombay-apse.action.io/#{packaged_container_name}"

      system "sudo rm -rf /var/lib/lxc/#{packaged_container_name}*"
      puts "File is available in s3://bombay-apse.action.io/#{packaged_container_name}"
    end
  end
end

