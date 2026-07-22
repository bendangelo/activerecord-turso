# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module ErrorTranslation
        def translate_exception(exception, message:, sql:, binds:)
          cause = exception.cause
          case cause
          when ::Turso::ConstraintException
            translate_constraint_error(message, sql, binds)
          when ::Turso::NotADatabaseException
            ActiveRecord::NoDatabaseError.new(message, sql: sql, binds: binds)
          when ::Turso::BusySnapshotException
            ActiveRecord::SerializationFailure.new(message, sql: sql, binds: binds)
          when ::Turso::BusyException
            ActiveRecord::Deadlocked.new(message, sql: sql, binds: binds)
          when ::Turso::ReadonlyException
            ActiveRecord::ReadOnlyRecord.new(message, sql: sql, binds: binds)
          when ::Turso::IoException, ::Turso::CorruptException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::DatabaseFullException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::InterruptException
            ActiveRecord::QueryCanceled.new(message, sql: sql, binds: binds)
          when ::Turso::MisuseException
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          else
            super
          end
        end

        private

        def translate_constraint_error(message, sql, binds)
          case message
          when /foreign key constraint|foreign key mismatch/i
            ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
          when /unique constraint|primary key/i
            ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
          else
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          end
        end
      end
    end
  end
end
