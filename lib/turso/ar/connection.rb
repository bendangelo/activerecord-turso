# frozen_string_literal: true

require "forwardable"

module Turso
  module AR
    class Connection
      extend Forwardable

      def_delegators :@db, :close, :closed?, :changes, :total_changes

      def initialize(config)
        @config = config
        @db = ::Turso::DB.new(config[:database].to_s,
          busy_timeout: config[:busy_timeout] || config[:timeout],
          query_timeout: config[:query_timeout])
      end

      def last_insert_rowid
        query("SELECT last_insert_rowid()").first&.values&.first.to_i
      end

      def raw_connection
        @db
      end

      def open?
        !@db.closed?
      end

      def disconnect!
        @db.close unless @db.closed?
      end

      def execute(sql, binds = [])
        @db.execute(sql, normalize_binds(binds))
        nil
      end

      def query(sql, params = [])
        @db.query(sql, normalize_binds(params))
      end

      def execute_batch(sql)
        sql.split(";").each do |stmt|
          s = stmt.strip
          @db.execute(s) unless s.empty?
        end
      end

      def prepare(sql)
        @db.instance_variable_get(:@database).connection.prepare(sql)
      end

      def busy_timeout=(ms)
        @db.busy_timeout = ms.to_i
      end

      def query_timeout=(ms)
        @db.query_timeout = ms.to_i
      end

      def interrupt
        @db.interrupt
      end

      private

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
