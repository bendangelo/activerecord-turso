# frozen_string_literal: true

require_relative "test_helper"

class TestConnection < Minitest::Test
  def test_open_memory_database
    conn = Turso::AR::Connection.new(database: ":memory:")
    refute conn.closed?
    conn.close
    assert conn.closed?
  end

  def test_execute_and_query
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (name TEXT)")
    conn.execute("INSERT INTO users VALUES (?)", ["Alice"])
    rows = conn.query("SELECT * FROM users")
    assert_equal [["Alice"]], rows.map(&:values)
  end

  def test_changes_and_last_insert_rowid
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    assert_equal 1, conn.changes
    assert_equal 1, conn.last_insert_rowid
  end

  def test_boolean_binds_are_normalized
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (name TEXT, active INTEGER)")
    conn.execute("INSERT INTO users VALUES (?, ?)", ["Alice", true])
    row = conn.query("SELECT active FROM users").first
    assert_equal 1, row["active"]
  end
end
