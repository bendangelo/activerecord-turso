# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module SchemaStatements
        def tables(name = nil)
          query_values(<<~SQL, "SCHEMA")
            SELECT name FROM sqlite_master
            WHERE type IN ('table', 'view')
              AND name NOT LIKE 'sqlite_%'
              AND name NOT LIKE 'fts_dir_%'
              AND name NOT LIKE 'sqlite_fts_%'
          SQL
        end

        def views
          query_values(<<~SQL, "SCHEMA")
            SELECT name FROM sqlite_master WHERE type = 'view'
          SQL
        end

        def virtual_tables
          query_values(<<~SQL, "SCHEMA")
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND sql LIKE '%CREATE VIRTUAL TABLE%'
          SQL
        end

        def indexes(table_name)
          super.reject { |idx| idx.name.to_s.start_with?("fts_dir_") || idx.name.to_s.start_with?("sqlite_fts_") }
        end

        def supports_virtual_tables?
          true
        end

        def create_virtual_table(table_name, type_name, columns_or_options = [], **options)
          type_name = type_name.to_s
          columns = columns_or_options.is_a?(Array) ? columns_or_options : (columns_or_options[:columns] || [])
          options = columns_or_options.is_a?(Hash) ? columns_or_options : options
          options_str = options_to_fts_options(options)
          execute("CREATE VIRTUAL TABLE #{quote_table_name(table_name)} USING #{type_name} (#{columns.join(", ")})#{options_str}")
        end

        def drop_virtual_table(table_name, **options)
          execute("DROP TABLE IF EXISTS #{quote_table_name(table_name)}")
        end

        def add_fts_index(table_name, columns, tokenizer: :default, weights: {})
          columns = Array(columns)
          name = "fts_#{table_name}_#{columns.join('_')}"
          weights_str = weights.map { |col, w| "#{col}=#{w}" }.join(",")
          with_clause = ["tokenizer = '#{tokenizer}'"]
          with_clause << "weights = '#{weights_str}'" unless weights_str.empty?

          execute(<<~SQL)
            CREATE INDEX #{quote_table_name(name)}
            ON #{quote_table_name(table_name)} USING fts (#{columns.join(", ")})
            WITH (#{with_clause.join(", ")})
          SQL
        end

        def remove_fts_index(table_name, name = nil)
          name ||= "fts_#{table_name}"
          execute("DROP INDEX IF EXISTS #{quote_table_name(name)}")
        end

        def fts_indexes(table_name)
          query_values(<<~SQL, "SCHEMA")
            SELECT name FROM sqlite_master
            WHERE type = 'index'
              AND tbl_name = #{quote(table_name)}
              AND sql LIKE '%USING fts%'
          SQL
        end

        def fts_match(_table_name, columns, query)
          cols = Array(columns).map { |c| quote_table_name(c) }.join(", ")
          Arel.sql("fts_match(#{cols}, #{quote(query)})")
        end

        def fts_score(_table_name, columns, query)
          cols = Array(columns).map { |c| quote_table_name(c) }.join(", ")
          Arel.sql("fts_score(#{cols}, #{quote(query)})")
        end

        private

        def options_to_fts_options(options)
          return "" if options.empty?
          " " + options.map { |k, v| "#{k}=#{v}" }.join(", ")
        end
      end
    end
  end
end
