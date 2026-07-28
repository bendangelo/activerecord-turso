# frozen_string_literal: true

require_relative "../support/test_case"

class SQLite3TransactionTest < ActiveRecord::TursoConformanceTestCase
  def test_raises_on_unsupported_isolation_level
    with_connection do |conn|
      assert_raises(ActiveRecord::TransactionIsolationError) do
        conn.transaction(requires_new: true, isolation: :something) do
          conn.transaction_manager.materialize_transactions
        end
      end
    end
  end

  private
    def with_connection(options = {})
      options = options.dup
      options[:database] = ActiveRecordTursoConformanceTest.database_path
      conn = ActiveRecord::ConnectionAdapters::TursoAdapter.new(options)
      yield(conn)
    ensure
      conn.disconnect! if conn
    end
end
