# frozen_string_literal: true

require_relative "lib/activerecord-turso/version"

Gem::Specification.new do |spec|
  spec.name = "activerecord-turso"
  spec.version = ActiveRecordTurso::VERSION
  spec.summary = "ActiveRecord adapter for Turso"
  spec.authors = ["Ben D'Angelo"]
  spec.license = "MIT"
  spec.files = Dir["lib/**/*", "README.md"]
  spec.required_ruby_version = ">= 3.2.0"
  spec.add_dependency "activerecord", ">= 8.0", "< 8.2"
  spec.add_dependency "turso", "~> 0.1"

  spec.add_development_dependency "irb"
end
