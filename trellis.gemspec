# frozen_string_literal: true

require_relative "lib/trellis/version"

Gem::Specification.new do |spec|
  spec.name        = "trellis"
  spec.version     = Trellis::VERSION
  spec.authors     = ["Jumpstart Lab"]
  spec.email       = ["jeff@jumpstartlab.com"]
  spec.summary     = "The fleet's shared decisions, in one place that can be changed once"
  spec.description = "Observability and heartbeat conventions for Jumpstart Lab apps. " \
                     "Inert without configuration; adoptable one app at a time."
  spec.homepage    = "https://github.com/JumpstartLab/trellis"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["allowed_push_host"] = "https://rubygems.org" # never pushed; consumed via git

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  # sentry-rails pulls sentry-ruby. Both are declared because Trellis calls into
  # each: the SDK for init, the railtie for Rails integration.
  spec.add_dependency "sentry-ruby", "~> 6.0"
  spec.add_dependency "sentry-rails", "~> 6.0"
end
