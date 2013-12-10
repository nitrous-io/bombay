module Bombay
  class Container
    attr_accessor :name, :playbook_name
    include Bombay::Bench

    def initialize(name, playbook_name)
      self.name = name
      self.playbook_name = playbook_name
    end

    def build!
      profile do
        ENV['ANSIBLE_CONFIG'] = "#{Bombay::ROOT}/config/ansible.container.cfg"
        system "ansible-playbook #{Bombay::ROOT}/ansible/#{self.name}/plays/#{self.playbook_name}.yml " +
          "-i #{Bombay::ROOT}/config/hosts.containers " +
          "--private-key=#{Dir.home}/.ansible/bombay"
      end
    end

    def deploy!
      profile do
        lxc_container_path = "/var/lib/lxc/#{self.name}"
        version = Time.now.to_i
        packaged_container_name = "#{self.name}_#{version}.tar.gz"

        if self.name == "dummy_container_template"
          version = 0
          packaged_container_name = "base_container_template_#{version}.tar.gz"
        end

        delete_from_container = [
          "rootfs/home/action/.ssh",
          "rootfs/home/action/.ansible",
          "rootfs/home/action/.cache",
          "rootfs/home/action/.bash_history",
          "rootfs/home/action/.bashrc",
          "rootfs/home/action/.viminfo",
          "rootfs/home/action/.gem",
          "rootfs/home/action/.bash_logout",
          "rootfs/home/action/.profile",
          "rootfs/home/action/*",
          "rootfs/etc/crontab",
          "rootfs/var/log/*",
          "rootfs/var/cache/*"
        ]

        raise ConfigFileMissingError if !File.exists?(lxc_container_path)

        delete_from_container.each { |p| system "sudo rm -rf #{lxc_container_path}/#{p}" }

        system "sudo bash -c 'echo #{version} > #{lxc_container_path}/VERSION'"

        root = "/var/lib/lxc"
        if self.name == "dummy_container_template"
          system "sudo rm -rf /tmp/base_container_template"
          system "sudo mv #{root}/#{self.name} /tmp/base_container_template"
          root = "/tmp"
        end
        system "cd #{root} && sudo tar cpvzf #{packaged_container_name} base_container_template"
        system "s3cmd put #{root}/#{packaged_container_name} s3://bombay-apse.action.io/#{packaged_container_name}"
        system "sudo rm -rf #{root}/#{packaged_container_name}*"
      end
    end
  end
end

