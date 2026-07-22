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
            ActiveRecord::Base.logger&.warn(
              "transaction(concurrent: true) is experimental and may break ActiveRecord model persistence. " \
              "See adapter documentation."
            )
            transaction_with_mvcc(options, &block)
          else
            super
          end
        end

        private

        def transaction_with_mvcc(options, &block)
          connect if @raw_connection.nil?

          unless @mvcc_enabled
            raise ActiveRecord::AdapterError,
                  "transaction(concurrent: true) requires journal_mode: 'mvcc' in database.yml"
          end

          if options[:requires_new] == false
            raise ActiveRecord::AdapterError,
                  "transaction(concurrent: true) is incompatible with nested transactions"
          end

          max_retries = @config.fetch(:concurrent_retry_limit, 50)
          base_delay_ms = @config.fetch(:concurrent_retry_base_ms, 2)
          retries = 0
          pinned_connection_id = @raw_connection.object_id

          loop do
            begin
              @raw_connection.execute("BEGIN CONCURRENT")
              result = yield
              @raw_connection.execute("COMMIT")
              return result
            rescue ActiveRecord::StatementInvalid => e
              rollback_if_active
              raise unless concurrent_conflict?(e) && retries < max_retries

              retries += 1
              verified!
              backoff(base_delay_ms, retries)

              unless @raw_connection.object_id == pinned_connection_id
                raise ActiveRecord::AdapterError,
                      "MVCC retry detected a different database connection. " \
                      "transaction(concurrent: true) must run on a pinned connection."
              end
            end
          end
        end

        def concurrent_conflict?(exception)
          cause = exception.cause
          conflict_classes = [::Turso::BusySnapshotException, ::Turso::BusyException]

          conflict_classes.any? { |klass| cause.is_a?(klass) } ||
            /snapshot conflict|busy snapshot|database is locked|cannot start a transaction within a transaction/i.match?(exception.message)
        end

        def rollback_if_active
          return unless @raw_connection && !@raw_connection.closed?
          @raw_connection.execute("ROLLBACK") rescue nil
        end

        def backoff(base_delay_ms, retries)
          sleep(base_delay_ms * retries / 1000.0)
        end

        def savepoint_name(name)
          "#{name}_sp"
        end
      end
    end
  end
end
