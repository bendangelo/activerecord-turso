# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module ErrorTranslation
        def translate_exception(exception, message:, sql:, binds:)
          cause = exception.cause
          case cause
          when ::Turso::ConstraintError
            translate_constraint_error(message, sql, binds)
          when ::Turso::NotADatabaseError
            ActiveRecord::NoDatabaseError.new(message, sql: sql, binds: binds)
          when ::Turso::BusySnapshotError
            ActiveRecord::SerializationFailure.new(message, sql: sql, binds: binds)
          when ::Turso::BusyError
            ActiveRecord::Deadlocked.new(message, sql: sql, binds: binds)
          when ::Turso::ReadonlyError
            ActiveRecord::ReadOnlyRecord.new(message, sql: sql, binds: binds)
          when ::Turso::IoError, ::Turso::CorruptError
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::DatabaseFullError
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          when ::Turso::InterruptError
            ActiveRecord::QueryCanceled.new(message, sql: sql, binds: binds)
          when ::Turso::MisuseError
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          else
            super
          end
        end

        private

        def translate_constraint_error(message, sql, binds)
          case message
          when /foreign key constraint/i
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
