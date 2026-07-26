# frozen_string_literal: true

require_relative "../test_helper"

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

  private

  def mvcc_enabled?
    ActiveRecordTursoTest.journal_mode == "mvcc"
  end
end
