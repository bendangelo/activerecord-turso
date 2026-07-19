# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module DatabaseStatements
        def execute(sql, name = nil)
          materialize_transactions
          raw_execute(sql, name)
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

          stmt = if prepare
            @statements[sql] ||= raw_connection.prepare(sql)
          else
            raw_connection.prepare(sql)
          end

          stmt.reset if prepare
          stmt.bind_positional(type_casted_binds) unless type_casted_binds.empty?

          begin
            if write_query?(sql)
              affected_rows = stmt.execute
              verified!
              notification_payload[:affected_rows] = affected_rows
              notification_payload[:row_count] = 0
              ActiveRecord::Result.empty(affected_rows: affected_rows)
            else
              columns = (0...stmt.column_count).map { |i| stmt.column_name(i) }
              rows = []
              while stmt.step == 1
                rows << stmt.row.to_a
              end
              affected_rows = raw_connection.changes
              verified!
              notification_payload[:affected_rows] = affected_rows
              notification_payload[:row_count] = rows.length
              type_map = build_type_map(stmt)
              ActiveRecord::Result.new(columns, rows, type_map, affected_rows: affected_rows)
            end
          ensure
            stmt.finalize unless prepare
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
