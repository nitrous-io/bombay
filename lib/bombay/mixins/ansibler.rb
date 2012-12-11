module Bombay
  module Ansibler
    VERSION = '0.9'.freeze

    def run_playbook(playbook, keypair, hosts, config, vars={})
      timestamp = Time.now.to_i

      ansible_hosts_file = File.join("/tmp", "ansible-hosts-#{timestamp}.cfg")
      ansible_config_file = File.join("/tmp", "ansible-config-#{timestamp}.cfg")

      File.open(ansible_hosts_file, 'w') { |f| f.puts(hosts) }
      File.open(ansible_config_file, 'w') { |f| f.puts(config) }

      ENV['ANSIBLE_CONFIG'] = ansible_config_file

      command = [
        "cd #{Bombay::ROOT}/ansible &&",
        "ansible-playbook #{playbook}",
        "-e \"#{vars.map { |k,v| "#{k}=#{v}" }.join(' ')}\"",
        "-i #{ansible_hosts_file}",
        "--private-key=#{keypair}"
      ]

      system command.join(' ')

      FileUtils.rm_rf(ansible_hosts_file)
      FileUtils.rm_rf(ansible_config_file)
    end

    def self.setup
      puts "Installing ansible dependencies"
      system "sudo apt-get -yy install python-setuptools"
      system "sudo easy_install jinja2 paramiko pyyaml"
      puts "Downloading ansible #{VERSION} from Github..."
      system "wget https://github.com/downloads/ansible/ansible/ansible-#{VERSION}.tar.gz --output-document=/tmp/ansible-#{VERSION}.tar.gz --quiet"
      puts "Expanding ansible #{VERSION}"
      system "tar -zxvf /tmp/ansible-#{VERSION}.tar.gz --directory=/tmp"
      puts "Setting up ansible #{VERSION}..."
      system "cd /tmp/ansible-#{VERSION} && sudo python setup.py install"
    end

  end
end
