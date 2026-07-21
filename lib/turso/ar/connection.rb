# frozen_string_literal: true

require "forwardable"

module Turso
  module AR
    class Connection
      extend Forwardable

      def_delegators :@db, :close, :closed?, :changes, :total_changes

      DEFAULT_BUSY_TIMEOUT_MS = 5000
      DEFAULT_QUERY_TIMEOUT_MS = 30_000

      def initialize(config)
        @config = config
        db_opts = {
          busy_timeout: config[:busy_timeout] || config[:timeout] || DEFAULT_BUSY_TIMEOUT_MS,
          query_timeout: config[:query_timeout] || DEFAULT_QUERY_TIMEOUT_MS
        }
        db_opts[:experimental_features] = config[:experimental_features] if config[:experimental_features]
        @db = ::Turso::Database.new(config[:database].to_s, **db_opts)
      end

      def last_insert_rowid
        query("SELECT last_insert_rowid()").first&.to_a&.first.to_i
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
        split_batch(sql).each do |stmt|
          @db.execute(stmt)
        end
      end

      def prepare(sql)
        @db.prepare(sql)
      end

      def busy_timeout=(ms)
        @db.busy_timeout = ms.to_i
      end

      def interrupt
        @db.interrupt
      end

      private

      def split_batch(sql)
        statements = []
        current = +""
        in_string = false
        in_line_comment = false
        in_block_comment = false
        i = 0
        while i < sql.length
          char = sql[i]
          next_char = sql[i + 1]

          if in_line_comment
            if char == "\n"
              in_line_comment = false
            end
            i += 1
            next
          end

          if in_block_comment
            if char == "*" && next_char == "/"
              in_block_comment = false
              i += 2
            else
              i += 1
            end
            next
          end

          if in_string
            if char == "'" && next_char == "'"
              current << char << next_char
              i += 2
              next
            elsif char == "'"
              in_string = false
              current << char
              i += 1
              next
            end
            current << char
            i += 1
            next
          end

          case char
          when "'"
            in_string = true
            current << char
          when "-"
            if next_char == "-"
              in_line_comment = true
              i += 2
              next
            end
            current << char
          when "#"
            in_line_comment = true
            i += 1
            next
          when "/"
            if next_char == "*"
              in_block_comment = true
              i += 2
              next
            end
            current << char
          when ";"
            stmt = current.strip
            statements << stmt unless stmt.empty?
            current = +""
          else
            current << char
          end
          i += 1
        end

        stmt = current.strip
        statements << stmt unless stmt.empty?
        statements
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
