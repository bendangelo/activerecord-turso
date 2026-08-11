# frozen_string_literal: true

require_relative "../test_helper"

class TestInterrupt < Minitest::Test
  def around
    cleanup_database
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end

  def test_interrupt_cancels_running_query
    conn = ActiveRecord::Base.connection
    conn.execute("SELECT 1")

    # The public Turso::Connection#interrupt wrapper is owned by the calling
    # thread/fiber and raises Turso::Exception when invoked from another thread,
    # so it cannot be used to cancel a query running on the main thread. The
    # underlying native connection has no such guard, so reach it directly.
    native = conn.raw_connection.instance_variable_get(:@db).instance_variable_get(:@native)

    interrupt_thread = Thread.new do
      sleep(0.05)
      native.interrupt
    end

    # execute_batch releases the GVL while running, so the interrupt thread can
    # acquire it and cancel the long-running query.
    err = assert_raises(::Turso::InterruptException) do
      conn.raw_connection.execute_batch("SELECT COUNT(*) FROM generate_series(1, 100000000)")
    end

    assert_match(/interrupt/i, err.message)
  ensure
    interrupt_thread&.join
  end
end
