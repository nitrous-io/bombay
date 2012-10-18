require "domainatrix"
require "fog"
require "active_support/all"

module Bombay
  ROOT = File.expand_path(File.dirname(__FILE__) + '/../')

  class AwsAuthenticationError      < RuntimeError; end
  class SecurityGroupMissingError   < RuntimeError; end
  class ConfigFileMissingError      < RuntimeError; end
  class DnsZoneMissingError         < RuntimeError; end
  class ElasticIpError              < RuntimeError; end
  class PrivateKeyDoesNotExistError < RuntimeError; end
end

require "bombay/version"
require "bombay/server"
require "bombay/security_rule"
require "bombay/security_group"
require "bombay/aws_authenticator"
require "bombay/ansible_runner"
