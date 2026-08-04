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

require "active_record/tasks/database_tasks"
require_relative "active_record/tasks/turso_database_tasks"

ActiveRecord::Tasks::DatabaseTasks.register_task(/turso/, "ActiveRecord::Tasks::TursoDatabaseTasks")

at_exit do
  ActiveRecord::Base.connection_pool&.disconnect! rescue nil
end
