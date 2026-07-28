# frozen_string_literal: true

module DdlHelper
  def with_example_table(connection, table_name, definition = nil)
    definition ||= <<~SQL
      id integer PRIMARY KEY AUTOINCREMENT,
      number integer
    SQL
    connection.execute("CREATE TABLE IF NOT EXISTS #{table_name}(#{definition})")
    yield
  ensure
    connection.execute("DROP TABLE IF EXISTS #{table_name}")
  end
end
