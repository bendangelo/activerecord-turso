# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module TransactionManagement
        def supports_savepoints?
          true
        end

        def begin_db_transaction
          execute("BEGIN DEFERRED")
        end

        def commit_db_transaction
          execute("COMMIT TRANSACTION")
        end

        def rollback_db_transaction
          execute("ROLLBACK TRANSACTION")
        end

        def create_savepoint(name = current_savepoint_name(true))
          execute("SAVEPOINT #{savepoint_name(name)}")
        end

        def rollback_to_savepoint(name = current_savepoint_name(true))
          execute("ROLLBACK TO SAVEPOINT #{savepoint_name(name)}")
        end

        def release_savepoint(name = current_savepoint_name(true))
          execute("RELEASE SAVEPOINT #{savepoint_name(name)}")
        end

        def transaction(requires_new: nil, isolation: nil, joinable: true, **options, &block)
          if options.delete(:concurrent)
            transaction_with_mvcc(options, &block)
          else
            super
          end
        end

        private

        def transaction_with_mvcc(options, &block)
          unless @mvcc_enabled
            raise ActiveRecord::AdapterError,
                  "transaction(concurrent: true) requires journal_mode: 'mvcc' in database.yml"
          end

          max_retries = @config.fetch(:concurrent_retry_limit, 50)
          base_delay_ms = @config.fetch(:concurrent_retry_base_ms, 2)
          retries = 0

          loop do
            begin
              raw_execute("BEGIN CONCURRENT", "TRANSACTION")
              yield
              raw_execute("COMMIT", "TRANSACTION")
              return
            rescue ActiveRecord::StatementInvalid => e
              raw_execute("ROLLBACK", "TRANSACTION") rescue nil
              raise unless concurrent_conflict?(e) && retries < max_retries

              retries += 1
              sleep(base_delay_ms * retries / 1000.0)
            end
          end
        end

        def concurrent_conflict?(exception)
          exception.cause.is_a?(::Turso::BusySnapshotError) ||
            exception.cause.is_a?(::Turso::BusyError) ||
            /snapshot conflict|busy snapshot|database is locked/i.match?(exception.message)
        end

        def savepoint_name(name)
          "#{name}_sp"
        end
      end
    end
  end
end
