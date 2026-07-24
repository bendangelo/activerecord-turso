# frozen_string_literal: true

require "forwardable"

module Turso
  module AR
    class Connection
      extend Forwardable

      def_delegators :@db, :close, :closed?, :changes, :total_changes,
                     :last_insert_rowid, :prepare, :interrupt, :busy_timeout=

      DEFAULT_BUSY_TIMEOUT_MS = 5000
      DEFAULT_QUERY_TIMEOUT_MS = 30_000

      def initialize(config)
        @config = config
        db_opts = {
          busy_timeout: config[:busy_timeout] || config[:timeout] || DEFAULT_BUSY_TIMEOUT_MS,
          query_timeout: config[:query_timeout] || DEFAULT_QUERY_TIMEOUT_MS
        }
        db_opts[:experimental_features] = config[:experimental_features] if config[:experimental_features]
        database = ::Turso::Database.new(config[:database].to_s, **db_opts)
        @db = database.connection
        @db.busy_timeout = db_opts[:busy_timeout]
        @db.query_timeout = db_opts[:query_timeout]
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
        @db.execute(sql, *normalize_binds(binds))
        nil
      end

      def query(sql, params = [])
        @db.query(sql, *normalize_binds(params))
      end

      def execute_batch(sql)
        @db.execute_batch(sql)
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
