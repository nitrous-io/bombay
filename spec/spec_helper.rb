require 'bombay'

require 'rspec'
require 'fakefs/safe'
require 'fakefs/spec_helpers'

require 'helpers/cloud_helpers'

module Bombay
  class Server
    def say(message); end
  end
end

RSpec.configure do |c|
  c.before(:all) { Fog.mock! }
  c.include      CloudHelpers
end
