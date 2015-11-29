# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'axe/version'

Gem::Specification.new do |spec|
  spec.name          = "axe"
  spec.version       = Axe::VERSION
  spec.authors       = ["Kris Leech"]
  spec.email         = ["kris.leech@gmail.com"]

  spec.summary       = "Micro framework for mapping handlers to Kafka topics"
  spec.description   = "Micro framework for mapping handlers to Kafka topics"

  spec.homepage      = "https://github.com/krisleech/axe"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'poseidon'
  spec.add_dependency 'snappy'
  spec.add_dependency 'retries'
  spec.add_dependency 'avro'
end
