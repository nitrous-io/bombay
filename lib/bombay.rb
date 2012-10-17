require "domainatrix"
require "fog"

require "bombay/version"
require "bombay/server"
require "bombay/security_rule"
require "bombay/security_group"
require "bombay/aws_authenticator"

module Bombay
  ROOT = File.expand_path(File.dirname(__FILE__) + '/../')
end
