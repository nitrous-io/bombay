require 'fileutils'
require 'yaml'

module Bombay
  class AwsAuthenticator
    AWS_CREDENTIALS_FILE = File.join(Dir.home, '.bombay', 'aws.yml')

    def self.set_credentials!(access_key = nil, secret_key = nil)
      write_credentials!(access_key, secret_key)
      load_credentials!
    end

    def self.write_credentials!(access_key, secret_key)
      FileUtils.mkdir_p(File.dirname(AWS_CREDENTIALS_FILE))

      File.open(AWS_CREDENTIALS_FILE, 'w') do |f|
        f.puts(YAML.dump(access_key: access_key, secret_key: secret_key))
      end

      FileUtils.chmod 0700, File.dirname(AWS_CREDENTIALS_FILE)
      FileUtils.chmod 0600, AWS_CREDENTIALS_FILE
    end

    def self.clear_credentials!
      FileUtils.rm_rf(AWS_CREDENTIALS_FILE) if File.exists?(AWS_CREDENTIALS_FILE)
    end

    def self.load_credentials!
      if File.exists?(AWS_CREDENTIALS_FILE)
        credentials = YAML.load(File.read(AWS_CREDENTIALS_FILE))
        ENV['AWS_ACCESS_KEY_ID'] = credentials[:access_key]
        ENV['AWS_SECRET_ACCESS_KEY'] = credentials[:secret_key]
      else
        nil
      end
    end
  end
end
