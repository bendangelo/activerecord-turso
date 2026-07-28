# frozen_string_literal: true

module ActiveRecord
  class TursoConformanceTestCase
    def current_adapter?(*types)
      types.any? do |type|
        ActiveRecord::ConnectionAdapters.const_defined?(type) &&
          ActiveRecord::Base.connection_pool.db_config.adapter_class <= ActiveRecord::ConnectionAdapters.const_get(type)
      end
    end

    def in_memory_db?
      ActiveRecord::Base.connection_pool.db_config.database == ":memory:"
    end

    def supports_savepoints?
      ActiveRecord::Base.lease_connection.supports_savepoints?
    end

    def supports_partial_index?
      ActiveRecord::Base.lease_connection.supports_partial_index?
    end

    def supports_expression_index?
      ActiveRecord::Base.lease_connection.supports_expression_index?
    end

    def supports_insert_returning?
      ActiveRecord::Base.lease_connection.supports_insert_returning?
    end

    def supports_virtual_columns?
      ActiveRecord::Base.lease_connection.supports_virtual_columns?
    end
  end
end
