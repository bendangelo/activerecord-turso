# frozen_string_literal: true

require_relative "../test_helper"

class TestMvcc < Minitest::Test
  def setup
    skip "MVCC tests require TURSO_TEST_JOURNAL_MODE=mvcc" unless ActiveRecordTursoTest.journal_mode == "mvcc"

    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS mvcc_counters (
        id INTEGER PRIMARY KEY,
        value INTEGER NOT NULL
      )
    SQL
    ActiveRecord::Base.connection.execute("DELETE FROM mvcc_counters")
    ActiveRecord::Base.connection.execute("INSERT INTO mvcc_counters (id, value) VALUES (1, 0)")
  end

  def test_concurrent_increment_with_retry
    threads = 4.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ActiveRecord::Base.connection.transaction(concurrent: true) do
            value = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
            ActiveRecord::Base.connection.execute("UPDATE mvcc_counters SET value = #{value.to_i + 1} WHERE id = 1")
          end
        end
      end
    end

    threads.each(&:join)
    final = ActiveRecord::Base.connection.query_value("SELECT value FROM mvcc_counters WHERE id = 1")
    assert_equal 4, final.to_i
  end
end
