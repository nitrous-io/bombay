require 'fileutils'

module Bombay
  class Container
    attr_accessor :name

    def initialize(name)
      self.name = name
    end

    def build!
      if !File.exists?(File.join(Bombay::ROOT, "ansible", "containers", name, "plays", "main.yml"))
        raise Bombay::ConfigFileMissingError
      end

      ENV['ANSIBLE_CONFIG'] = "#{Bombay::ROOT}/ansible/config/ansible.container.cfg"
      system "ansible-playbook #{Bombay::ROOT}/ansible/containers/#{self.name}/plays/main.yml " +
             "-i #{Bombay::ROOT}/ansible/config/hosts.containers " +
             "--private-key=#{Dir.home}/.ansible/bombay"
    end

    def deploy!
      lxc_container_path = "/var/lib/lxc/#{self.name}"
      tmp_container_path = "/tmp/#{self.name}"
      version = Time.now.to_i
      packaged_container_name = "#{self.name}_#{version}.tar.gz"

      delete_from_container = [
        "rootfs/home/action/.ssh",
        "rootfs/home/action/.ansible",
        "rootfs/home/action/.cache",
        "roots/home/action/.bash_history",
        "rootfs/var/log/*",
        "rootfs/var/cache/apt/archives/*"
      ]

      if !File.exists?(lxc_container_path)
        raise ConfigFileMissingError
      end

      if File.exists?(tmp_container_path)
        system "sudo rm -rf #{tmp_container_path}"
      end

      # Copy the container over
      system "sudo cp -pr #{lxc_container_path} /tmp/"

      delete_from_container.each do |path|
        system "sudo rm -rf #{tmp_container_path}/#{path}"
      end

      system "sudo bash -c 'echo #{version} > #{tmp_container_path}/VERSION'"
      system "cd /tmp && sudo tar cpvzf #{packaged_container_name} #{self.name}"
      system "s3cmd put /tmp/#{packaged_container_name} s3://bombay-apse.action.io/#{packaged_container_name}"

      system "sudo rm -rf /tmp/#{self.name}*"
      puts "File is available in s3://bombay-apse.action.io/#{packaged_container_name}"
    end
  end
end

