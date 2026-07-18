# frozen_string_literal: true

module Turso
  module AR
    class Connection
      def initialize(config = {})
        @config = config
        @db = Turso::DB.new(
          config[:database].to_s,
          busy_timeout: config[:timeout]&.to_i,
          query_timeout: config[:query_timeout]&.to_i
        )
      end

      def execute(sql, binds = [])
        @db.execute(sql, normalize_binds(binds))
        nil
      end

      def query(sql, binds = [])
        @db.query(sql, normalize_binds(binds)).to_a
      end

      def close
        @db.close
      end

      def closed?
        @db.closed?
      end

      def changes
        query("SELECT changes()").first&.values&.first.to_i
      end

      def last_insert_rowid
        query("SELECT last_insert_rowid()").first&.values&.first.to_i
      end

      def busy_timeout=(ms)
        raw_connection.busy_timeout = ms.to_i
      end

      def query_timeout=(ms)
        raw_connection.query_timeout = ms.to_i
      end

      def interrupt
        raw_connection.interrupt
      end

      private

      def raw_connection
        @db.instance_variable_get(:@database).connection
      end

      def normalize_binds(binds)
        binds.map do |value|
          case value
          when true then 1
          when false then 0
          else value
          end
        end
      end
    end
  end
end
