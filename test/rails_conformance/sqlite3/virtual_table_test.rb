# frozen_string_literal: true

require_relative "../support/test_case"

class SQLite3VirtualTableTest < ActiveRecord::TursoConformanceTestCase
  def setup
    super
    skip "Turso uses Tantivy FTS instead of fts5 virtual tables"
  end
end
