# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module ErrorTranslation
        def translate_exception(exception, message:, sql:, binds:)
          case exception
          when ::Turso::ConstraintException
            translate_constraint_error(message, sql, binds)
          when ::Turso::NotADatabaseException
            ActiveRecord::NoDatabaseError.new(message, connection_pool: pool)
          when ::Turso::BusySnapshotException
            ActiveRecord::SerializationFailure.new(message, sql: sql, binds: binds)
          when ::Turso::BusyException
            ActiveRecordTurso::BusyError.new(message, sql: sql, binds: binds)
          when ::Turso::ReadonlyException
            ActiveRecord::ReadOnlyRecord.new(message)
          when ::Turso::IoException, ::Turso::CorruptException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::DatabaseFullException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::InterruptException
            ActiveRecord::QueryCanceled.new(message, sql: sql, binds: binds)
          when ::Turso::MisuseException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::Exception
            ActiveRecord::ConnectionFailed.new(message, connection_pool: pool)
          else
            super
          end
        end

        def retryable_connection_error?(exception)
          super || exception.is_a?(::Turso::Exception)
        end

        def retryable_query_error?(exception)
          super || exception.is_a?(::Turso::Exception)
        end

        private

        def translate_constraint_error(message, sql, binds)
          case message
          when /foreign key constraint|foreign key mismatch/i
            ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
          when /unique constraint|primary key/i
            ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
          when /NOT NULL|cannot be NULL/i
            ActiveRecord::NotNullViolation.new(message, sql: sql, binds: binds)
          else
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          end
        end
      end
    end
  end
end
