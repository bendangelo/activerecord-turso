# frozen_string_literal: true

require_relative "../test_helper"
require "minitest/mock"

class MvccTest < Minitest::Test
  def around
    cleanup_database
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS mvcc_counters (
        id INTEGER PRIMARY KEY,
        value INTEGER NOT NULL DEFAULT 0
      )
    SQL
    ActiveRecord::Base.connection.execute("DELETE FROM mvcc_counters")
    ActiveRecord::Base.connection.execute("INSERT INTO mvcc_counters (id, value) VALUES (1, 0)")
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end

  def test_concurrent_transaction_commits
    skip unless mvcc_enabled?

    result = ActiveRecord::Base.connection.transaction(concurrent: true) do
      value = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
      ActiveRecord::Base.connection.execute("UPDATE mvcc_counters SET value = #{value + 1} WHERE id = 1")
      "done"
    end

    assert_equal "done", result
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1").to_i
    assert_equal 1, final
  end

  def test_mvcc_raises_when_not_enabled
    establish_connection(journal_mode: "wal")
    conn = ActiveRecord::Base.connection

    refute conn.instance_variable_get(:@mvcc_enabled)

    err = assert_raises(ActiveRecord::AdapterError) do
      conn.transaction(concurrent: true) { }
    end
    assert_match(/requires journal_mode.*mvcc/i, err.message)
  ensure
    restore_base_connection
  end

  def test_mvcc_rejects_nested_transaction
    skip unless mvcc_enabled?
    conn = ActiveRecord::Base.connection

    # NOTE: The public `transaction` API captures `requires_new:` as its own
    # keyword argument, so it is never forwarded to `transaction_with_mvcc`.
    # Invoking the private method directly is the only way to exercise the
    # nested-transaction guard (transaction_management.rb:57-60). See report.
    err = assert_raises(ActiveRecord::AdapterError) do
      conn.send(:transaction_with_mvcc, { requires_new: false }) { }
    end
    assert_match(/incompatible with nested/i, err.message)
  end

  def test_mvcc_retries_on_snapshot_conflict
    skip unless mvcc_enabled?
    conn = ActiveRecord::Base.connection
    conn.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS mvcc_retry (
        id INTEGER PRIMARY KEY,
        value INTEGER NOT NULL
      )
    SQL
    conn.execute("DELETE FROM mvcc_retry")

    raw = conn.raw_connection
    commit_calls = 0
    raw.stub(:execute, lambda { |sql, *binds|
      if sql == "COMMIT"
        commit_calls += 1
        raise conflict_error if commit_calls == 1
      end
      raw.__minitest_stub__execute(sql, *binds)
    }) do
      result = conn.transaction(concurrent: true) do
        conn.execute("INSERT INTO mvcc_retry (id, value) VALUES (1, 10)")
        "done"
      end
      assert_equal "done", result
    end

    assert_equal 2, commit_calls
    count = conn.query_value("SELECT COUNT(*) FROM mvcc_retry WHERE id = 1").to_i
    assert_equal 1, count
  end

  def test_mvcc_exhausts_retries_and_raises
    skip unless mvcc_enabled?
    establish_connection(journal_mode: "mvcc", concurrent_retry_limit: 2, concurrent_retry_base_ms: 0)
    conn = ActiveRecord::Base.connection

    raw = conn.raw_connection
    commit_calls = 0
    raw.stub(:execute, lambda { |sql, *binds|
      if sql == "COMMIT"
        commit_calls += 1
        raise conflict_error
      end
      raw.__minitest_stub__execute(sql, *binds)
    }) do
      assert_raises(ActiveRecord::StatementInvalid) do
        conn.transaction(concurrent: true) { }
      end
    end

    assert_equal 3, commit_calls
  ensure
    restore_base_connection
  end

  def test_mvcc_detects_connection_switch_during_retry
    skip unless mvcc_enabled?
    conn = ActiveRecord::Base.connection
    raw = conn.raw_connection
    new_raw = ::Turso::AR::Connection.new(
      database: ActiveRecordTursoTest.database_path,
      busy_timeout: 5000,
      query_timeout: 30_000
    )

    raw.stub(:execute, lambda { |sql, *binds|
      if sql == "COMMIT"
        conn.instance_variable_set(:@raw_connection, new_raw)
        raise conflict_error
      end
      raw.__minitest_stub__execute(sql, *binds)
    }) do
      err = assert_raises(ActiveRecord::AdapterError) do
        conn.transaction(concurrent: true) { }
      end
      assert_match(/different database connection/i, err.message)
    end
  ensure
    conn&.instance_variable_set(:@raw_connection, raw) if conn && raw
    new_raw&.close
  end

  def test_mvcc_real_snapshot_conflict_retries
    skip unless mvcc_enabled?
    # KNOWN BUG: A real write-write conflict surfaces as ActiveRecord::ConnectionFailed
    # (Turso::Exception) via error_translation.rb:27-28, which transaction_with_mvcc's
    # rescue ActiveRecord::StatementInvalid does not catch, and concurrent_conflict?
    # does not match "Write-write conflict". MVCC retry never fires on real conflicts.
    # Un-skip once the gem handles write-write conflicts.
    skip "MVCC retry does not handle real write-write conflicts (surfaces as ConnectionFailed, not StatementInvalid)"

    conn = ActiveRecord::Base.connection
    conn.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS mvcc_real_conflict (
        id INTEGER PRIMARY KEY,
        value INTEGER DEFAULT 0
      )
    SQL
    conn.execute("DELETE FROM mvcc_real_conflict")
    conn.execute("INSERT INTO mvcc_real_conflict (id, value) VALUES (1, 0)")

    other = ::Turso::Database.new(ActiveRecordTursoTest.database_path)
    other.execute("PRAGMA journal_mode = mvcc")

    attempts = 0
    result = conn.transaction(concurrent: true) do
      attempts += 1
      if attempts == 1
        other.execute("BEGIN CONCURRENT")
        other.execute("UPDATE mvcc_real_conflict SET value = value + 1 WHERE id = 1")
        other.execute("COMMIT")
      end
      conn.execute("UPDATE mvcc_real_conflict SET value = value + 1 WHERE id = 1")
      "done"
    end

    assert_equal "done", result
    assert_operator attempts, :>=, 2
  ensure
    other&.close
  end

  def test_mvcc_custom_retry_config
    skip unless mvcc_enabled?
    establish_connection(journal_mode: "mvcc", concurrent_retry_limit: 5, concurrent_retry_base_ms: 1)
    conn = ActiveRecord::Base.connection

    config = conn.instance_variable_get(:@config)
    assert_equal 5, config[:concurrent_retry_limit]
    assert_equal 1, config[:concurrent_retry_base_ms]
  ensure
    restore_base_connection
  end

  def test_concurrent_conflict_matches_message
    skip unless mvcc_enabled?
    conn = ActiveRecord::Base.connection

    assert conn.send(:concurrent_conflict?, ActiveRecord::StatementInvalid.new("database is locked"))
    assert conn.send(:concurrent_conflict?, ActiveRecord::StatementInvalid.new("snapshot conflict"))
    refute conn.send(:concurrent_conflict?, ActiveRecord::StatementInvalid.new("some other error"))
  end

  private

  def mvcc_enabled?
    ActiveRecordTursoTest.journal_mode == "mvcc"
  end

  def establish_connection(overrides = {})
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config.merge(overrides))
    ActiveRecord::Base.connection.connect
  end

  def restore_base_connection
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
  end

  def conflict_error(message = "database is locked")
    begin
      raise ::Turso::BusySnapshotException, message
    rescue ::Turso::BusySnapshotException
      raise ActiveRecord::StatementInvalid.new(message)
    end
  end
end
