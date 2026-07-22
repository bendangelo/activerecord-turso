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
          db_config[:experimental_features] = Array(db_config[:experimental_features])
          ::Turso::AR::Connection.new(db_config)
        end
        end

        def active?
          return false unless @raw_connection
          !@raw_connection.closed?
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
              ActiveRecord::Base.logger&.warn(
                "Turso journal_mode: mvcc is experimental. Concurrent transactions require careful connection handling."
              )
            end
          end

          execute("PRAGMA foreign_keys = ON")

          timeout = @config[:busy_timeout] || @config[:timeout] || 5000
          @raw_connection.busy_timeout = timeout


        end
      end
    end
  end
end
