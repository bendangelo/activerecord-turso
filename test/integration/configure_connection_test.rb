# frozen_string_literal: true

require_relative "../test_helper"

class TestConfigureConnection < Minitest::Test
  def around
    cleanup_database
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    cleanup_database
  end

  def test_wal_autocheckpoint_defaults_to_1000
    statements = connect_and_capture_configure_sql({})

    assert_includes statements, "PRAGMA wal_autocheckpoint = 1000"
  end

  def test_wal_autocheckpoint_custom_value
    statements = connect_and_capture_configure_sql(wal_autocheckpoint: 500)

    assert_includes statements, "PRAGMA wal_autocheckpoint = 500"
  end

  def test_busy_timeout_propagates_to_raw_connection
    establish_connection(busy_timeout: 7000)
    conn = ActiveRecord::Base.connection
    conn.execute("CREATE TABLE IF NOT EXISTS busy_items (id INTEGER PRIMARY KEY)")
    conn.execute("INSERT INTO busy_items VALUES (1)")

    locker = ::Turso::Database.new(ActiveRecordTursoTest.database_path)
    locker.execute("BEGIN EXCLUSIVE")

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      conn.raw_connection.execute("INSERT INTO busy_items VALUES (2)")
      flunk "expected Turso::BusyException"
    rescue ::Turso::BusyException
      # expected: busy_timeout elapsed and the write was rejected
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

    # Turso::Connection exposes busy_timeout= but no busy_timeout getter, so we
    # verify propagation behaviorally: a write against a held EXCLUSIVE lock must
    # block for ~7000ms before surfacing BusyException (tolerance 1s).
    assert_operator elapsed, :>=, 6.0,
      "expected busy_timeout 7000 to hold the write for ~7s, blocked only #{elapsed.round(2)}s"
  ensure
    locker&.execute("ROLLBACK") rescue nil
    locker&.close rescue nil
  end

  def test_query_timeout_propagates_to_raw_connection
    establish_connection(query_timeout: 15_000)

    raw = ActiveRecord::Base.connection.raw_connection

    assert_equal 15_000, raw.query_timeout
  end

  def test_foreign_keys_enabled_by_default
    establish_connection

    value = ActiveRecord::Base.connection.query_value("PRAGMA foreign_keys")

    assert_equal 1, value
  end

  private

  def establish_connection(overrides = {})
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config.merge(overrides))
    ActiveRecord::Base.connection.connect
  end

  # The libsql binding returns an empty result set for "PRAGMA wal_autocheckpoint"
  # read, so the value cannot be read back via query_value. Instead, capture the
  # exact PRAGMA statements configure_connection sends to the raw connection.
  def connect_and_capture_configure_sql(overrides)
    establish_connection(overrides)
    conn = ActiveRecord::Base.connection
    statements = []
    raw = conn.raw_connection
    raw.define_singleton_method(:prepare) do |sql|
      statements << sql
      super(sql)
    end
    conn.configure_connection
    statements
  end
end
