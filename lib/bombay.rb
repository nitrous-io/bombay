require "domainatrix"
require "fog"
require "yaml"
require "ipaddress"
require "active_support/all"
require "set"
require "fileutils"
require "erb"
require 'commander/user_interaction'

module Bombay
  ROOT = File.expand_path(File.dirname(__FILE__) + '/../')
end

require "bombay/version"

require "bombay/categories/security_group+bombay"
require "bombay/mixins/ansibler"
require "bombay/mixins/aws"

require "bombay/security_groups/security_rule"
require "bombay/security_groups/security_group"
require "bombay/security_groups/security_group_collection"

require "bombay/block_devices/block_device"
require "bombay/block_devices/block_device_collection"

require "bombay/servers/server_variables"
require "bombay/servers/server"
require "bombay/servers/server_collection"

require "bombay/container"

