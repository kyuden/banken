# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'banken/version'

Gem::Specification.new do |spec|
  spec.name          = "banken"
  spec.version       = Banken::VERSION
  spec.authors       = ["kyuden"]
  spec.email         = ["msmsms.um@gmail.com"]

  spec.summary       = %q{Simple and lightweight authorization solution for Rails.}
  spec.description   = %q{Banken provides a set of helpers which restricts what resources a given user is allowed to access.}
  spec.homepage      = "https://github.com/kyuden/banken"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'activesupport', '>= 3.0.0'

  spec.add_development_dependency "activemodel", ">= 3.0.0"
  spec.add_development_dependency "actionpack", ">= 3.0.0"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
end
