# frozen_string_literal: true

require_relative "test_helper"

class TestStatementPool < Minitest::Test
  def test_pool_stores_and_finalizes_statements
    config = { database: ":memory:", adapter: "turso" }
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(config)
    adapter.execute("SELECT 1") # triggers lazy connect
    pool = adapter.send(:build_statement_pool)

    stmt = adapter.raw_connection.prepare("SELECT 1")
    pool["SELECT 1"] = stmt
    assert_same stmt, pool["SELECT 1"]

    pool.reset
    assert_raises(::Turso::Error) { stmt.step }
  ensure
    adapter&.disconnect!
  end
end
