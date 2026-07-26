# frozen_string_literal: true

require_relative "../test_helper"

class TimeoutInterruptTest < Minitest::Test
  def around
    cleanup_database
    config = ActiveRecordTursoTest.base_config.merge(query_timeout: 100)
    ActiveRecord::Base.establish_connection(config)
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end

  def test_query_timeout_raises_query_canceled
    assert_raises(ActiveRecord::QueryCanceled) do
      ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM generate_series(1, 100000000)"
      )
    end
  end
end
