require "domainatrix"
require "fog"
require "active_support/all"

module Bombay
  ROOT = File.expand_path(File.dirname(__FILE__) + '/../')

  class AwsAuthenticationError          < RuntimeError; end
  class AwsSecurityGroupMissingError    < RuntimeError; end
  class AwsDnsZoneMissingError          < RuntimeError; end
  class AwsElasticIpError               < RuntimeError; end
  class ConfigFileMissingError          < RuntimeError; end
  class PrivateKeyDoesNotExistError     < RuntimeError; end
end

require "bombay/version"
require "bombay/aws_authenticator"
require "bombay/container"
require "bombay/security_rule"
require "bombay/security_group"
require "bombay/server"
