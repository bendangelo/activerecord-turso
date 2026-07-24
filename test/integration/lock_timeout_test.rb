# frozen_string_literal: true

require_relative "../test_helper"

class TestLockTimeout < Minitest::Test
  def setup
    @db_path = File.join(ActiveRecordTursoTest::TMP, "lock_test_#{Process.pid}_#{object_id}.sqlite3")
  end

  def teardown
    FileUtils.rm_f(@db_path)
    Dir["#{@db_path}-*"].each { |f| FileUtils.rm_f(f) }
  end

  def test_busy_timeout_raises_busy_error
    db1 = ::Turso::Database.new(@db_path)
    db1.execute("CREATE TABLE lock_items (id INTEGER PRIMARY KEY)")
    db1.execute("INSERT INTO lock_items VALUES (1)")

    db2 = ::Turso::Database.new(@db_path)
    db2.execute("CREATE TABLE IF NOT EXISTS lock_items (id INTEGER PRIMARY KEY)")

    db1.execute("BEGIN EXCLUSIVE")
    db2.busy_timeout = 50

    assert_raises(::Turso::BusyException) do
      db2.execute("INSERT INTO lock_items VALUES (2)")
    end
  ensure
    db1&.execute("ROLLBACK") rescue nil
    db2&.close rescue nil
  end
end
