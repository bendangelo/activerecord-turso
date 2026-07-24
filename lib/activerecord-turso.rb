# frozen_string_literal: true

require "active_record"
require "turso"

require_relative "activerecord-turso/error"
require_relative "turso/ar/connection"
require_relative "active_record/connection_adapters/turso_adapter"

ActiveRecord::ConnectionAdapters.register(
  "turso",
  "ActiveRecord::ConnectionAdapters::TursoAdapter",
  "active_record/connection_adapters/turso_adapter"
)
