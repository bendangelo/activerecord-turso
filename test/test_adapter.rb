# frozen_string_literal: true

require_relative "test_helper"

class TestAdapter < Minitest::Test
  def setup
    @config = { database: ":memory:", adapter: "turso" }
  end

  def test_adapter_name
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    assert_equal "Turso", adapter.adapter_name
  ensure
    adapter&.disconnect!
  end

  def test_exec_query
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    adapter.execute("CREATE TABLE users (name TEXT)")
    adapter.execute("INSERT INTO users VALUES ('Alice')")
    result = adapter.exec_query("SELECT * FROM users")
    assert_equal ["name"], result.columns
    assert_equal [["Alice"]], result.rows
  ensure
    adapter&.disconnect!
  end

  def test_pragmas
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    result = adapter.exec_query("PRAGMA foreign_keys")
    assert_equal [[1]], result.rows
  ensure
    adapter&.disconnect!
  end

  def test_unique_violation
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    adapter.execute("CREATE TABLE users (email TEXT UNIQUE)")
    adapter.execute("INSERT INTO users VALUES ('a@b.com')")

    assert_raises(ActiveRecord::RecordNotUnique) do
      adapter.execute("INSERT INTO users VALUES ('a@b.com')")
    end
  ensure
    adapter&.disconnect!
  end

  def test_statement_pool_can_be_built
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    pool = adapter.send(:build_statement_pool)
    assert_kind_of ActiveRecord::ConnectionAdapters::StatementPool, pool
    assert_nil pool["SELECT 1"]
  ensure
    adapter&.disconnect!
  end

  def test_reset_reconnects
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    adapter.execute("CREATE TABLE users (name TEXT)")
    adapter.reset!
    refute adapter.instance_variable_get(:@raw_connection).nil?
  ensure
    adapter&.disconnect!
  end

  def test_check_version_does_not_raise
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    assert adapter.send(:check_version)
  ensure
    adapter&.disconnect!
  end

  def test_supports_flags
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    assert adapter.supports_ddl_transactions?
    assert adapter.supports_savepoints?
    refute adapter.supports_transaction_isolation?
  ensure
    adapter&.disconnect!
  end

  def test_binds_are_cast
    adapter = ActiveRecord::ConnectionAdapters::TursoAdapter.new(@config)
    adapter.execute("CREATE TABLE users (name TEXT, active INTEGER)")

    name_attr = ActiveRecord::Relation::QueryAttribute.new("name", "Alice", ActiveRecord::Type::String.new)
    active_attr = ActiveRecord::Relation::QueryAttribute.new("active", true, ActiveRecord::Type::Boolean.new)

    adapter.exec_query("INSERT INTO users VALUES (?, ?)", nil, [name_attr, active_attr])
    result = adapter.exec_query("SELECT * FROM users")
    assert_equal [["Alice", 1]], result.rows
  ensure
    adapter&.disconnect!
  end
end
