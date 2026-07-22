# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest"
gem "rake"

gemfile_dir = File.dirname(__FILE__)
local_turso = File.expand_path("~/Projects/turso/bindings/ruby/gem")
ci_turso = File.expand_path("../turso/bindings/ruby/gem", gemfile_dir)

if File.directory?(local_turso)
  gem "turso", path: local_turso
elsif File.directory?(ci_turso)
  gem "turso", path: ci_turso
else
  gem "turso"
end

gem "sqlite3"

group :test do
  gem "minitest-around"
end
