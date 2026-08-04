# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/test_*.rb", "test/integration/**/*_test.rb"]
end

namespace :test do
  Rake::TestTask.new(:conformance) do |t|
    t.libs << "test"
    t.test_files = FileList["test/rails_conformance/sqlite3/**/*_test.rb"]
  end

  Rake::TestTask.new(:bench) do |t|
    t.libs << "test"
    t.test_files = FileList["test/integration/bulk_insert_benchmark_test.rb"]
    t.warning = false
  end
end

task default: :test
