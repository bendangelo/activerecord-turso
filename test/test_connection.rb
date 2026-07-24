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
    assert_equal [["Alice"]], rows.map(&:to_a)
  end

  def test_changes_and_last_insert_rowid
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    assert_equal 1, conn.changes
    assert_equal 1, conn.last_insert_rowid
  end

  def test_execute_batch
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute_batch(<<~SQL)
      CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT);
      INSERT INTO users (name) VALUES ('Alice');
      INSERT INTO users (name) VALUES ('Bob');
    SQL
    rows = conn.query("SELECT name FROM users ORDER BY name")
    assert_equal ["Alice", "Bob"], rows.map { |r| r["name"] }
  end

  def test_execute_batch_with_semicolon_in_string
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute_batch(<<~SQL)
      CREATE TABLE users (name TEXT);
      INSERT INTO users (name) VALUES ('a;b');
    SQL
    rows = conn.query("SELECT name FROM users")
    assert_equal ["a;b"], rows.map { |r| r["name"] }
  end

  def test_changes_and_total_changes
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    conn.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
    assert_equal 1, conn.changes
    assert_equal 2, conn.total_changes
  end

  def test_boolean_binds_are_normalized
    conn = Turso::AR::Connection.new(database: ":memory:")
    conn.execute("CREATE TABLE users (name TEXT, active INTEGER)")
    conn.execute("INSERT INTO users VALUES (?, ?)", ["Alice", true])
    row = conn.query("SELECT active FROM users").first
    assert_equal 1, row["active"]
  end

  def test_ar_connection_uses_turso_connection
    conn = Turso::AR::Connection.new(database: ":memory:")
    assert_kind_of Turso::Connection, conn.raw_connection
  end
end
