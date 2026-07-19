# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module DatabaseStatements
        def execute(sql, name = nil)
          materialize_transactions
          raw_execute(sql, name)
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false)
          materialize_transactions

          type_casted_binds = type_casted_binds(binds)
          log(sql, name, binds, type_casted_binds) do
            with_raw_connection do |conn|
              stmt = conn.prepare(sql)
              stmt.bind_positional(type_casted_binds) unless type_casted_binds.empty?
              result = build_result(stmt)
              stmt.finalize
              result
            end
          end
        end

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil, returning = nil)
          if returning && supports_insert_returning?
            return exec_query(sql, name, binds)
          end

          materialize_transactions

          type_casted_binds = type_casted_binds(binds)
          log(sql, name, binds, type_casted_binds) do
            with_raw_connection do |conn|
              stmt = conn.prepare(sql)
              stmt.bind_positional(type_casted_binds) unless type_casted_binds.empty?
              stmt.execute
              last_id = pk ? last_inserted_id(sql) : nil
              stmt.finalize
              last_id
            end
          end
        end

        def last_inserted_id(sql)
          @raw_connection.last_insert_rowid
        end

        def returning_column_values(result)
          [@raw_connection.last_insert_rowid]
        end

        def default_timezone
          ActiveRecord.default_timezone
        end

        def combine_named_bind_params(binds)
          binds
        end

        def select_rows(arel, name = nil)
          arel = arel_from_relation(arel)
          sql, binds = to_sql_and_binds(arel)
          type_casted_binds = type_casted_binds(binds)

          log(sql, name, binds, type_casted_binds) do
            with_raw_connection do |conn|
              stmt = conn.prepare(sql)
              stmt.bind_positional(type_casted_binds) unless type_casted_binds.empty?
              rows = []
              while stmt.step == 1
                rows << stmt.row.to_a
              end
              stmt.finalize
              rows
            end
          end
        end

        def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
          if batch
            raw_connection.execute_batch(sql)
            return ActiveRecord::Result.empty(affected_rows: 0)
          end

          if write_query?(sql)
            raw_connection.execute(sql, type_casted_binds)
            affected_rows = raw_connection.changes
            verified!
            notification_payload[:affected_rows] = affected_rows
            notification_payload[:row_count] = 0
            ActiveRecord::Result.empty(affected_rows: affected_rows)
          else
            result = raw_connection.query(sql, type_casted_binds)
            columns = result.column_names
            rows = result.map(&:values)
            affected_rows = raw_connection.changes
            verified!
            notification_payload[:affected_rows] = affected_rows
            notification_payload[:row_count] = rows.length
            ActiveRecord::Result.new(columns, rows, nil, affected_rows: affected_rows)
          end
        end

        def disable_referential_integrity
          old_foreign_keys = query_value("PRAGMA foreign_keys")
          old_defer_foreign_keys = query_value("PRAGMA defer_foreign_keys")

          begin
            execute("PRAGMA defer_foreign_keys = ON")
            execute("PRAGMA foreign_keys = OFF")
            yield
          ensure
            if old_defer_foreign_keys
              execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
            end
            execute("PRAGMA foreign_keys = #{old_foreign_keys}")
          end
        end

        private

        def build_result(stmt)
          columns = (0...stmt.column_count).map { |i| stmt.column_name(i) }
          type_map = build_type_map(stmt)
          rows = []
          while stmt.step == 1
            rows << stmt.row.to_a
          end
          ActiveRecord::Result.new(columns, rows, type_map)
        end

        def build_type_map(stmt)
          type_map = {}
          count = stmt.column_count
          count.times do |i|
            decltype = stmt.respond_to?(:column_decltype) ? stmt.column_decltype(i) : nil
            next unless decltype
            type_map[i] = decltype_to_type(decltype)
          end
          type_map
        end

        def decltype_to_type(decltype)
          case decltype.to_s.upcase
          when /INT/ then Type::Integer.new
          when /REAL|FLOA|DOUB/ then Type::Float.new
          when /DEC|NUM/ then Type::Decimal.new
          when /BOOL/ then Type::Boolean.new
          when /DATETIME/ then Type::DateTime.new
          when /DATE/ then Type::Date.new
          when /JSON/ then Type::Json.new
          when /BLOB/ then Type::Binary.new
          else Type::String.new
          end
        end
      end
    end
  end
end
