# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class TursoAdapter < SQLite3Adapter
      module ConnectionManagement
        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods
          def new_client(config)
            db_config = config.symbolize_keys.merge(:timeout => config[:timeout] || 5000)
            ::Turso::AR::Connection.new(db_config)
          end
        end

        def active?
          @raw_connection && !@raw_connection.closed?
        rescue ::Turso::Error
          false
        end

        def reconnect!(**)
          @lock.synchronize do
            disconnect!
            @raw_connection = self.class.new_client(@config)
            configure_connection
          end
        end

        def disconnect!
          @lock.synchronize do
            @raw_connection&.close
            @raw_connection = nil
          end
        end

        def raw_connection
          @lock.synchronize { @raw_connection }
        end

        def jdbc?
          false
        end

        def configure_connection
          @mvcc_enabled = false

          if @config[:journal_mode]
            mode = @config[:journal_mode].to_s
            execute("PRAGMA journal_mode = #{mode}")
            if @config[:journal_mode].to_s.downcase == "mvcc"
              @mvcc_enabled = true
            end
          end

          execute("PRAGMA foreign_keys = ON")

          if @config[:timeout] || @config[:busy_timeout]
            timeout = @config[:busy_timeout] || @config[:timeout]
            @raw_connection.busy_timeout = timeout
          end

          if @config[:query_timeout]
            @raw_connection.query_timeout = @config[:query_timeout]
          end
        end
      end
    end
  end
end
