module Bombay
  class AnsibleRunner
    def self.run_container_play(name)
      ENV['ANSIBLE_CONFIG'] = 'ansible/config/ansible.container.cfg'
      system "ansible-playbook ansible/containers/#{name}/plays/main.yml " +
             "-i ansible/config/hosts.containers " +
             "--private-key=#{Dir.home}/.ansible/bombay"
    end
  end
end

