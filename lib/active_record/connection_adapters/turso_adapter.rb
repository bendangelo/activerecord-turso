# frozen_string_literal: true

require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/sqlite3/column"
require "active_record/connection_adapters/sqlite3/quoting"
require "active_record/connection_adapters/sqlite3/explain_pretty_printer"
require "active_record/connection_adapters/sqlite3/database_statements"
require "active_record/connection_adapters/sqlite3/schema_creation"
require "active_record/connection_adapters/sqlite3/schema_definitions"
require "active_record/connection_adapters/sqlite3/schema_dumper"
require "active_record/connection_adapters/sqlite3/schema_statements"

AR_8_1 = Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new("8.1.0")

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < AbstractAdapter
      ADAPTER_NAME = "Turso"

      class << self
        def new_client(config)
          Turso::AR::Connection.new(config)
        end

        def native_database_types
          NATIVE_DATABASE_TYPES
        end

        def dbconsole(config, options = {})
          raise NotImplementedError, "Turso adapter does not support dbconsole"
        end
      end

      include SQLite3::Quoting
      include SQLite3::SchemaStatements
      include SQLite3::DatabaseStatements

      NATIVE_DATABASE_TYPES = {
        primary_key: "integer PRIMARY KEY AUTOINCREMENT NOT NULL",
        string:      { name: "varchar" },
        text:        { name: "text" },
        integer:     { name: "integer" },
        bigint:      { name: "integer" },
        float:       { name: "float" },
        decimal:     { name: "decimal" },
        datetime:    { name: "datetime" },
        time:        { name: "time" },
        date:        { name: "date" },
        binary:      { name: "blob" },
        boolean:     { name: "boolean" },
        json:        { name: "json" }
      }.freeze

      DEFAULT_PRAGMAS = {
        "foreign_keys" => true,
        "journal_mode" => :wal,
        "synchronous"  => :normal,
        "cache_size"   => 2000
      }.freeze

      class StatementPool < ConnectionAdapters::StatementPool
        def initialize(*args)
          # AR 8.0: StatementPool.new(connection, limit)
          # AR 8.1: StatementPool.new(limit)
          super(args.last)
        end

        def [](_sql); nil; end
        def []=(_sql, _stmt); end
        def key?(_sql); false; end
        def clear; end
        def reset; end
      end

      def initialize(...)
        super

        @memory_database = @config[:database].to_s == ":memory:"

        if @config[:database].to_s.empty?
          raise ArgumentError, "No database file specified. Missing argument: database"
        end

        unless @memory_database
          if defined?(Rails.root) && Rails.root
            @config[:database] = File.expand_path(@config[:database], Rails.root)
          end
          dirname = File.dirname(@config[:database])
          unless File.directory?(dirname)
            begin
              FileUtils.mkdir_p(dirname)
            rescue SystemCallError
              raise ActiveRecord::NoDatabaseError.new(connection_pool: @pool)
            end
          end
        end
      end

      def database_exists?
        @memory_database || File.exist?(@config[:database].to_s)
      end

      def supports_ddl_transactions? = true
      def supports_savepoints? = true
      def supports_transaction_isolation? = false
      def supports_partial_index? = true
      def supports_expression_index? = true
      def requires_reloading? = true
      def supports_foreign_keys? = true
      def supports_check_constraints? = true
      def supports_views? = true
      def supports_json? = true
      def supports_datetime_with_precision? = true
      def supports_insert_on_conflict? = true
      def supports_insert_returning? = false
      def supports_common_table_expressions? = true
      def supports_concurrent_connections? = !@memory_database
      def supports_index_sort_order? = true
      def supports_explain? = true
      def supports_lazy_transactions? = true
      def supports_deferrable_constraints? = true

      def active?
        if connected?
          verified!
          true
        end
      end

      def connected?
        !(@raw_connection.nil? || @raw_connection.closed?)
      end

      def disconnect!
        super
        @raw_connection&.close rescue nil
        @raw_connection = nil
      end

      def reconnect
        disconnect!
        connect
      end

      def encoding
        "UTF-8"
      end

      def default_prepared_statements
        false
      end

      def supports_virtual_columns?
        database_version >= "3.31.0"
      end

      def get_database_version
        version = query_value("SELECT sqlite_version(*)", "SCHEMA")
        ActiveRecord::ConnectionAdapters::AbstractAdapter::Version.new(version)
      end

      private

      COLLATE_REGEX = /.*"(\w+)".*collate\s+"(\w+)".*/i
      PRIMARY_KEY_AUTOINCREMENT_REGEX = /.*"(\w+)".+PRIMARY KEY AUTOINCREMENT/i
      GENERATED_ALWAYS_AS_REGEX = /.*"(\w+)".+GENERATED ALWAYS AS \((.+)\) (?:STORED|VIRTUAL)/i
      UNQUOTED_OPEN_PARENS_REGEX = /\((?![^'"]*['"][^'"]*$)/
      FINAL_CLOSE_PARENS_REGEX = /\);*\z/
      FK_REGEX = /.*FOREIGN KEY\s+\("([^"]+)"\)\s+REFERENCES\s+"(\w+)"\s+\("(\w+)"\)/
      DEFERRABLE_REGEX = /DEFERRABLE INITIALLY (\w+)/

      def arel_visitor
        Arel::Visitors::SQLite.new(self)
      end

      def build_statement_pool
        limit = self.class.type_cast_config_to_integer(@config[:statement_limit])
        if AR_8_1
          StatementPool.new(limit)
        else
          StatementPool.new(self, limit)
        end
      end

      def connect
        @raw_connection = self.class.new_client(@config)
      rescue Turso::Error => e
        raise ActiveRecord::ConnectionNotEstablished, e.message
      end

      def quote_string(s)
        s.gsub("'", "''")
      end

      def shared_cache?
        false
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
          columns = result.first&.keys || []
          rows = result.map(&:values)
          affected_rows = raw_connection.changes
          verified!
          notification_payload[:affected_rows] = affected_rows
          notification_payload[:row_count] = rows.length
          ActiveRecord::Result.new(columns, rows, nil, affected_rows: affected_rows)
        end
      end

      unless AR_8_1
        def exec_query(sql, name = "SQL", binds = [], prepare: false)
          type_casted_binds = type_casted_binds(binds)
          result = @raw_connection.query(sql, type_casted_binds)
          columns = result.first&.keys || []
          rows = result.map(&:values)
          ActiveRecord::Result.new(columns, rows)
        end

        def execute(sql, name = nil)
          @raw_connection.execute(sql)
          nil
        end
      end

      def last_inserted_id(_result)
        @raw_connection.last_insert_rowid
      end

      def table_structure(table_name)
        structure = table_info(table_name)
        raise ActiveRecord::StatementInvalid.new("Could not find table '#{table_name}'", connection_pool: @pool) if structure.empty?
        table_structure_with_collation(table_name, structure)
      end
      alias column_definitions table_structure

      def returning_column_values(result)
        [@raw_connection.last_insert_rowid]
      end

      def build_insert_sql(insert)
        sql = +"INSERT #{insert.into} #{insert.values_list}"

        if insert.skip_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
        elsif insert.update_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
          if insert.raw_update_sql?
            sql << insert.raw_update_sql
          else
            sql << insert.touch_model_timestamps_unless { |column| "#{column} IS excluded.#{column}" }
            sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
          end
        end

        sql
      end

      def bind_params_length
        999
      end

      def extract_value_from_default(default)
        case default
        when /^null$/i
          nil
        when /^'([^|]*)'$/m
          $1.gsub("''", "'")
        when /^"([^|]*)"$/m
          $1.gsub('""', '"')
        when /\A-?\d+(\.\d*)?\z/
          $&
        when /x'(.*)'/
          [ $1 ].pack("H*")
        when "TRUE", "FALSE"
          default
        else
          nil
        end
      end

      def extract_default_function(default_value, default)
        default if has_default_function?(default_value, default)
      end

      def has_default_function?(default_value, default)
        !default_value && %r{\w+\(.*\)|CURRENT_TIME|CURRENT_DATE|CURRENT_TIMESTAMP|\|\|}.match?(default)
      end

      def invalid_alter_table_type?(type, options)
        type == :primary_key || options[:primary_key] ||
          options[:null] == false && options[:default].nil? ||
          (type == :virtual && options[:stored])
      end

      def table_info(table_name)
        if supports_virtual_columns?
          internal_exec_query("PRAGMA table_xinfo(#{quote_table_name(table_name)})", "SCHEMA", allow_retry: true)
        else
          internal_exec_query("PRAGMA table_info(#{quote_table_name(table_name)})", "SCHEMA", allow_retry: true)
        end
      end

      def table_structure_with_collation(table_name, basic_structure)
        collation_hash = {}
        auto_increments = {}
        generated_columns = {}

        column_strings = table_structure_sql(table_name, basic_structure.map { |column| column["name"] })

        if column_strings.any?
          column_strings.each do |column_string|
            collation_hash[$1] = $2 if COLLATE_REGEX =~ column_string
            auto_increments[$1] = true if PRIMARY_KEY_AUTOINCREMENT_REGEX =~ column_string
            generated_columns[$1] = $2 if GENERATED_ALWAYS_AS_REGEX =~ column_string
          end

          basic_structure.map do |column|
            column_name = column["name"]

            if collation_hash.has_key? column_name
              column["collation"] = collation_hash[column_name]
            end

            if auto_increments.has_key?(column_name)
              column["auto_increment"] = true
            end

            if generated_columns.has_key?(column_name)
              column["dflt_value"] = generated_columns[column_name]
            end

            column
          end
        else
          basic_structure.to_a
        end
      end

      def table_structure_sql(table_name, column_names = nil)
        unless column_names
          column_info = table_info(table_name)
          column_names = column_info.map { |column| column["name"] }
        end

        sql = <<~SQL
          SELECT sql FROM
            (SELECT * FROM sqlite_master UNION ALL
             SELECT * FROM sqlite_temp_master)
          WHERE type = 'table' AND name = #{quote(table_name)}
        SQL

        result = query_value(sql, "SCHEMA")
        return [] unless result

        result.partition(UNQUOTED_OPEN_PARENS_REGEX)
              .last
              .sub(FINAL_CLOSE_PARENS_REGEX, "")
              .split(/,(?=\s(?:CONSTRAINT|"(?:#{Regexp.union(column_names).source})"))/i)
              .map(&:strip)
      end

      def configure_connection
        if @config[:timeout]
          timeout = self.class.type_cast_config_to_integer(@config[:timeout])
          @raw_connection.busy_timeout = timeout
        end

        pragmas = @config.fetch(:pragmas, {}).stringify_keys
        DEFAULT_PRAGMAS.merge(pragmas).each do |pragma, value|
          execute("PRAGMA #{pragma} = #{value}")
        end
      end

      def translate_exception(exception, message:, sql:, binds:)
        case exception
        when Turso::ConstraintError
          if message.match?(/UNIQUE constraint failed/i)
            RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif message.match?(/FOREIGN KEY constraint failed/i)
            InvalidForeignKey.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif message.match?(/NOT NULL constraint failed/i)
            NotNullViolation.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif message.match?(/CHECK constraint failed/i)
            CheckViolation.new(message, sql: sql, binds: binds, connection_pool: @pool)
          else
            StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
          end
        when Turso::BusyError, Turso::BusySnapshotError, Turso::InterruptError
          StatementTimeout.new(message, sql: sql, binds: binds, connection_pool: @pool)
        when Turso::ReadonlyError
          ReadOnlyRecord.new(message)
        when Turso::IoError
          ConnectionNotEstablished.new(exception, connection_pool: @pool)
        when Turso::CorruptError, Turso::NotADatabaseError
          NoDatabaseError.new(connection_pool: @pool)
        else
          StatementInvalid.new(message, sql: sql, binds: binds, connection_pool: @pool)
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
          execute("PRAGMA defer_foreign_keys = #{old_defer_foreign_keys}")
          execute("PRAGMA foreign_keys = #{old_foreign_keys}")
        end
      end

      def primary_keys(table_name)
        pks = table_structure(table_name).select { |f| f["pk"] > 0 }
        pks.sort_by { |f| f["pk"] }.map { |f| f["name"] }
      end

      def foreign_keys(table_name)
        fk_info = internal_exec_query("PRAGMA foreign_key_list(#{quote(table_name)})", "SCHEMA")
        fk_defs = table_structure_sql(table_name)
                    .select do |column_string|
                      column_string.start_with?("CONSTRAINT") &&
                      column_string.include?("FOREIGN KEY")
                    end
                    .to_h do |fk_string|
                      _, from, table, to = fk_string.match(FK_REGEX).to_a
                      _, mode = fk_string.match(DEFERRABLE_REGEX).to_a
                      deferred = mode&.downcase&.to_sym || false
                      [[table, from, to], deferred]
                    end

        grouped_fk = fk_info.group_by { |row| row["id"] }.values.each { |group| group.sort_by! { |row| row["seq"] } }
        grouped_fk.map do |group|
          row = group.first
          options = {
            on_delete: extract_foreign_key_action(row["on_delete"]),
            on_update: extract_foreign_key_action(row["on_update"]),
            deferrable: fk_defs[[row["table"], row["from"], row["to"]]]
          }

          if group.one?
            options[:column] = row["from"]
            options[:primary_key] = row["to"]
          else
            options[:column] = group.map { |row| row["from"] }
            options[:primary_key] = group.map { |row| row["to"] }
          end
          ForeignKeyDefinition.new(table_name, row["table"], options)
        end
      end

      def alter_table(
        table_name,
        foreign_keys = foreign_keys(table_name),
        check_constraints = check_constraints(table_name),
        **options
      )
        altered_table_name = "a#{table_name}"

        caller = lambda do |definition|
          rename = options[:rename] || {}
          foreign_keys.each do |fk|
            if column = rename[fk.options[:column]]
              fk.options[:column] = column
            end
            to_table = strip_table_name_prefix_and_suffix(fk.to_table)
            definition.foreign_key(to_table, **fk.options)
          end

          check_constraints.each do |chk|
            definition.check_constraint(chk.expression, **chk.options)
          end

          yield definition if block_given?
        end

        disable_referential_integrity do
          transaction do
            move_table(table_name, altered_table_name, options.merge(temporary: true))
            move_table(altered_table_name, table_name, &caller)
          end
        end
      end

      def move_table(from, to, options = {}, &block)
        copy_table(from, to, options, &block)
        drop_table(from)
      end

      def copy_table(from, to, options = {})
        from_primary_key = primary_key(from)
        options[:id] = false
        create_table(to, **options) do |definition|
          @definition = definition
          if from_primary_key.is_a?(Array)
            @definition.primary_keys from_primary_key
          end

          columns(from).each do |column|
            column_name = options[:rename] ?
              (options[:rename][column.name] ||
               options[:rename][column.name.to_sym] ||
               column.name) : column.name

            column_options = {
              limit: column.limit,
              precision: column.precision,
              scale: column.scale,
              null: column.null,
              collation: column.collation,
              primary_key: column_name == from_primary_key
            }

            if column.virtual?
              column_options[:as] = column.default_function
              column_options[:stored] = column.virtual_stored?
              column_options[:type] = column.type
            elsif column.has_default?
              default = column.fetch_cast_type(self).deserialize(column.default)
              default = -> { column.default_function } if default.nil?

              unless column.auto_increment?
                column_options[:default] = default
              end
            end

            column_type = column.virtual? ? :virtual : (column.bigint? ? :bigint : column.type)
            @definition.column(column_name, column_type, **column_options)
          end

          yield @definition if block_given?
        end
        copy_table_indexes(from, to, options[:rename] || {})

        columns_to_copy = @definition.columns.reject { |col| col.options.key?(:as) }.map(&:name)
        copy_table_contents(from, to,
          columns_to_copy,
          options[:rename] || {})
      end

      def copy_table_indexes(from, to, rename = {})
        indexes(from).each do |index|
          name = index.name
          if to == "a#{from}"
            name = "t#{name}"
          elsif from == "a#{to}"
            name = name[1..-1]
          end

          columns = index.columns
          if columns.is_a?(Array)
            to_column_names = columns(to).map(&:name)
            columns = columns.map { |c| rename[c] || c }.select do |column|
              to_column_names.include?(column)
            end
          end

          unless columns.empty?
            options = { name: name.gsub(/(^|_)(#{from})_/, "\\1#{to}_"), internal: true }
            options[:unique] = true if index.unique
            options[:where] = index.where if index.where
            options[:order] = index.orders if index.orders
            add_index(to, columns, **options)
          end
        end
      end

      def copy_table_contents(from, to, columns, rename = {})
        column_mappings = Hash[columns.map { |name| [name, name] }]
        rename.each { |a| column_mappings[a.last] = a.first }
        from_columns = columns(from).collect(&:name)
        columns = columns.find_all { |col| from_columns.include?(column_mappings[col]) }
        from_columns_to_copy = columns.map { |col| column_mappings[col] }
        quoted_columns = columns.map { |col| quote_column_name(col) } * ","
        quoted_from_columns = from_columns_to_copy.map { |col| quote_column_name(col) } * ","

        internal_exec_query("INSERT INTO #{quote_table_name(to)} (#{quoted_columns})
                   SELECT #{quoted_from_columns} FROM #{quote_table_name(from)}")
      end
    end
  end
end
