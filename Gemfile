# frozen_string_literal: true

source "https://rubygems.org"

gemspec
gem "minitest"
gem "rake"
if File.directory?(File.expand_path("~/Projects/turso/bindings/ruby/gem"))
  gem "turso", path: "~/Projects/turso/bindings/ruby/gem"
else
  gem "turso"
end
gem "sqlite3"

group :test do
  gem "minitest-around"
end
