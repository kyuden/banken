# frozen_string_literal: true

require_relative "lib/banken/version"

Gem::Specification.new do |spec|
  spec.name          = "banken"
  spec.version       = Banken::VERSION
  spec.authors       = ["kyuden"]
  spec.email         = ["msmsms.um@gmail.com"]

  spec.summary       = "Simple and lightweight authorization solution for Rails."
  spec.description   = "Banken provides a set of helpers which restricts what resources a given user is allowed to access."
  spec.homepage      = "https://github.com/kyuden/banken"
  spec.license       = "MIT"

  spec.metadata = {
    "source_code_uri"       => spec.homepage,
    "changelog_uri"         => "#{spec.homepage}/blob/master/CHANGELOG.md",
    "bug_tracker_uri"       => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files         = Dir.glob("lib/**/*", base: __dir__).select { |f| File.file?(File.join(__dir__, f)) } +
                       %w[README.md CHANGELOG.md LICENSE.txt SECURITY.md]
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.3"

  spec.add_dependency "activesupport", ">= 7.1"

  spec.add_development_dependency "activemodel", ">= 7.1"
  spec.add_development_dependency "actionpack", ">= 7.1"
  spec.add_development_dependency "railties", ">= 7.1"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "yard"
end
