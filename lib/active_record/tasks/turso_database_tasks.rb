# frozen_string_literal: true

require "active_record/tasks/database_tasks"

module ActiveRecord
  module Tasks
    class TursoDatabaseTasks < SQLiteDatabaseTasks
      def create
        establish_connection(configuration)
        path = configuration.database
        return if path == ":memory:"

        FileUtils.mkdir_p(File.dirname(path))
        ActiveRecord::Base.establish_connection(configuration)
        connection
      end

      def drop
        path = configuration.database
        return if path == ":memory:"

        disconnect!
        FileUtils.rm_f(path)
        FileUtils.rm_f("#{path}-wal")
        FileUtils.rm_f("#{path}-shm")
      end

      def purge
        drop
        create
      end

      def charset
        "UTF-8"
      end

      def charset_collation
        nil
      end

      def structure_dump(filename, extra_flags)
        establish_connection(configuration)
        io = File.open(filename, "w")
        io.puts("PRAGMA foreign_keys = OFF;")

        tables = connection.query_values(<<~SQL, "SCHEMA")
          SELECT name FROM sqlite_master
          WHERE type = 'table'
            AND name NOT LIKE 'sqlite_%'
            AND name NOT LIKE '__turso_internal_%'
          ORDER BY name
        SQL

        tables.each do |table|
          sql = connection.query_value(<<~SQL, "SCHEMA")
            SELECT sql FROM sqlite_master WHERE name = #{connection.quote(table)}
          SQL
          io.puts("#{sql};") if sql
        end

        indexes = connection.query_values(<<~SQL, "SCHEMA")
          SELECT name FROM sqlite_master
          WHERE type = 'index'
            AND name NOT LIKE 'sqlite_%'
            AND sql IS NOT NULL
          ORDER BY name
        SQL

        indexes.each do |index|
          sql = connection.query_value(<<~SQL, "SCHEMA")
            SELECT sql FROM sqlite_master WHERE name = #{connection.quote(index)}
          SQL
          io.puts("#{sql};") if sql
        end

        views = connection.query_values(<<~SQL, "SCHEMA")
          SELECT name FROM sqlite_master
          WHERE type = 'view'
            AND name NOT LIKE 'sqlite_%'
          ORDER BY name
        SQL

        views.each do |view|
          sql = connection.query_value(<<~SQL, "SCHEMA")
            SELECT sql FROM sqlite_master WHERE name = #{connection.quote(view)}
          SQL
          io.puts("#{sql};") if sql
        end

        io.puts("PRAGMA foreign_keys = ON;")
        io.close
      end

      def structure_load(filename, extra_flags)
        establish_connection(configuration)
        sql = File.read(filename)
        connection.execute_batch(sql)
      end

      private

      def configuration
        @configuration
      end

      def connection
        ActiveRecord::Base.connection
      end

      def establish_connection(config)
        @configuration = config
        ActiveRecord::Base.establish_connection(config)
      end

      def disconnect!
        ActiveRecord::Base.connection_pool.disconnect!
      end
    end
  end
end
