# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'bombay/version'

Gem::Specification.new do |gem|
  gem.name          = "bombay"
  gem.version       = Bombay::VERSION
  gem.authors       = ["arunthampi", "liangzan"]
  gem.email         = ["arun@action.io", "zan@action.io"]
  gem.description   = %q{bombay is the server/container creation tool for action.io}
  gem.summary       = %q{bombay is the server/container creation tool for action.io}
  gem.homepage      = "https://www.action.io"

  gem.add_dependency  "fog",            "~> 1.10.0"
  gem.add_dependency  "domainatrix",    "~> 0.0.11"
  gem.add_dependency  "commander",      "~> 4.1.2"
  gem.add_dependency  "activesupport",  "~> 3.2.8"
  gem.add_dependency  "ipaddress",      "~> 0.8.0"

  gem.add_development_dependency  "rspec",  "~> 2.12.0"
  gem.add_development_dependency  "fakefs", "~> 0.4.2"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]
end
