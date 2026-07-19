# frozen_string_literal: true

require "active_record/connection_adapters/sqlite3_adapter"

Dir[File.expand_path("turso_adapter/*.rb", __dir__)].each { |f| require f }

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      include ConnectionManagement
      include DatabaseStatements
      include TransactionManagement
      include SchemaStatements
      include ErrorTranslation

      ADAPTER_NAME = "Turso"

      def supports_ddl_transactions?
        true
      end

      def supports_insert_returning?
        false
      end

      def supports_transaction_isolation?
        false
      end

      def supports_check_constraint?
        true
      end

      def supports_explain?
        true
      end

      def explain(arel, binds = [])
        sql = "EXPLAIN QUERY PLAN " + to_sql(arel, binds)
        result = exec_query(sql, "EXPLAIN", binds)
        SQLite3::ExplainPrettyPrinter.new.pp(result)
      end

      def default_prepared_statements
        false
      end

      def database_file_exists?
        File.exist?(@config[:database])
      end

      def connect
        @raw_connection = self.class.new_client(@connection_parameters)
        configure_connection
      rescue ::Turso::Error => e
        raise ActiveRecord::ConnectionNotEstablished, e.message
      end

      def check_version
        true
      end

      def encoding
        "UTF-8"
      end

      private

      def initialize_type_map(m)
        super
        m.register_type(%r(boolean)i, Type::Boolean.new)
      end
    end
  end
end
