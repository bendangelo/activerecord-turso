# frozen_string_literal: true

module LoadSchemaHelper
  def load_schema_file(filename)
    schema_path = File.join(SCHEMA_ROOT, filename)
    ActiveRecord::Base.connection.execute(File.read(schema_path))
  end
end
