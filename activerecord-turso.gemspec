# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "activerecord-turso"
  spec.version = "0.1.0"
  spec.summary = "ActiveRecord adapter for Turso"
  spec.authors = ["Ben D'Angelo"]
  spec.license = "MIT"
  spec.files = Dir["lib/**/*", "README.md"]
  spec.required_ruby_version = ">= 3.0.0"
  spec.add_dependency "activerecord", "~> 8.1"
  spec.add_dependency "turso", "~> 0.1"
end
