# frozen_string_literal: true

require_relative "../test_helper"

class TestFiberConcurrency < Minitest::Test
  def test_fiber_cannot_reuse_connection_from_another_fiber
    skip unless defined?(Fiber)
    db = ::Turso::Database.new(":memory:")
    db.execute("CREATE TABLE t (x)")
    conn = db.connection

    fiber = Fiber.new do
      assert_raises(::Turso::Exception) { conn.execute("SELECT 1") }
    end
    fiber.resume
  end

  def test_fiber_can_use_own_connection
    skip unless defined?(Fiber)
    fiber = Fiber.new do
      db = ::Turso::Database.new(":memory:")
      db.execute("CREATE TABLE t (x)")
      db.execute("INSERT INTO t VALUES (42)")
      db.query("SELECT x FROM t").first["x"]
    end
    assert_equal 42, fiber.resume
  end
end
