# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      class StatementPool < ConnectionAdapters::StatementPool
        alias reset clear

        private

        def dealloc(stmt)
          stmt.finalize
        rescue ::Turso::Error
        end
      end
    end
  end
end
