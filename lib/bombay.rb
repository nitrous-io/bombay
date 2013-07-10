module Bombay
  ROOT = File.expand_path(File.dirname(__FILE__) + '/../')
end

require "bombay/version"
require "bombay/mixins/ansibler"
require "bombay/container"
require "bombay/template"
