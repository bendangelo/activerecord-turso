# frozen_string_literal: true

require_relative "../test_helper"

class ConnectionRecord < ActiveRecord::Base
  self.table_name = "connection_records"
end

class TestConnectionManagement < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :connection_records, force: true do |t|
        t.string :name
      end
    end
  end

  def test_connection_is_active
    conn = ActiveRecord::Base.connection
    assert conn.active?
  end

  def test_connection_is_inactive_after_disconnect
    conn = ActiveRecord::Base.connection
    conn.disconnect!
    refute conn.active?
  end

  def test_reconnect_restores_connection
    conn = ActiveRecord::Base.connection
    original = conn.raw_connection
    conn.reconnect!
    refute_equal original, conn.raw_connection
    assert conn.active?
  end

  def test_pool_checks_out_distinct_connections
    conn_a = ActiveRecord::Base.connection_pool.checkout
    conn_b = ActiveRecord::Base.connection_pool.checkout
    conn_a.verify!
    conn_b.verify!
    assert conn_a.raw_connection
    assert conn_b.raw_connection
    refute_equal conn_a.raw_connection.object_id, conn_b.raw_connection.object_id
  ensure
    ActiveRecord::Base.connection_pool.checkin(conn_a) if conn_a
    ActiveRecord::Base.connection_pool.checkin(conn_b) if conn_b
  end

  def test_disconnect_all_releases_pool
    ActiveRecord::Base.connection.execute("INSERT INTO connection_records (name) VALUES ('x')")
    ActiveRecord::Base.connection_pool.disconnect!
    refute ActiveRecord::Base.connection.active? if ActiveRecord::Base.connected?
  end

  def test_execute_after_reconnect
    conn = ActiveRecord::Base.connection
    conn.reconnect!
    assert conn.execute("SELECT 1")
  end

  def test_pool_connections_are_independent
    threads = 3.times.map do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do |conn|
          conn.execute("INSERT INTO connection_records (name) VALUES ('thread-#{i}')")
          conn.execute("SELECT name FROM connection_records").first
        end
      end
    end

    results = threads.map(&:value)
    assert_equal 3, results.size
    assert_equal 3, ConnectionRecord.count
  end

  def test_reconnect_restores_foreign_keys_pragma
    conn = ActiveRecord::Base.connection
    conn.reconnect!
    assert conn.active?
    assert_equal 1, conn.query_value("PRAGMA foreign_keys")
  end
end
