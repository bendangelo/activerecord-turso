# frozen_string_literal: true

require_relative "test_helper"
require "active_record/tasks/database_tasks"

class RailsDatabaseTasksTest < Minitest::Test
  include ActiveRecordTursoTest

  def around
    cleanup_database
    yield
  ensure
    cleanup_database
  end

  def build_task
    config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test", "primary", ActiveRecordTursoTest.base_config
    )
    ActiveRecord::Tasks::TursoDatabaseTasks.new(config)
  end

  def test_create_creates_database_file
    path = ActiveRecordTursoTest.database_path
    refute File.exist?(path)

    task = build_task
    task.create
    assert File.exist?(path)
  end

  def test_drop_removes_database_file
    path = ActiveRecordTursoTest.database_path
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection.execute("CREATE TABLE x (id INTEGER)")
    ActiveRecord::Base.connection_pool.disconnect!

    task = build_task
    task.drop
    refute File.exist?(path)
    refute File.exist?("#{path}-wal")
  end

  def test_structure_dump_and_load_round_trip
    dump = File.join(ActiveRecordTursoTest::TMP, "structure.sql")

    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    ActiveRecord::Base.connection.execute("CREATE INDEX idx_users_name ON users (name)")
    ActiveRecord::Base.connection_pool.disconnect!

    task = build_task
    task.structure_dump(dump, nil)

    sql = File.read(dump)
    assert_match(/CREATE TABLE users/, sql)
    assert_match(/CREATE INDEX idx_users_name/, sql)

    task.drop
    task.structure_load(dump, nil)

    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    tables = ActiveRecord::Base.connection.tables
    assert_includes tables, "users"
  ensure
    FileUtils.rm_f(dump)
  end

  def test_structure_dump_and_load_round_trip_with_fts_index
    dump = File.join(ActiveRecordTursoTest::TMP, "fts_structure.sql")

    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    connection = ActiveRecord::Base.connection
    connection.create_table(:messages) { |table| table.text :content, null: false }
    connection.add_fts_index(:messages, :content, tokenizer: :ngram)
    ActiveRecord::Base.connection_pool.disconnect!

    task = build_task
    task.structure_dump(dump, nil)

    sql = File.read(dump)
    assert_match(/CREATE INDEX .* USING fts \(content\)/, sql)
    assert_match(/tokenizer = 'ngram'/, sql)
    refute_match(/__turso_internal_/, sql)

    task.drop
    task.structure_load(dump, nil)

    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    connection = ActiveRecord::Base.connection
    connection.execute("INSERT INTO messages (content) VALUES ('日本語の部分一致検索')")

    assert_equal 1, connection.select_value(<<~SQL)
      SELECT COUNT(*) FROM messages WHERE fts_match(content, '部分一致')
    SQL
  ensure
    FileUtils.rm_f(dump)
  end

  def test_charset
    task = build_task
    assert_equal "UTF-8", task.charset
  end

  def test_purge_removes_and_recreates
    path = ActiveRecordTursoTest.database_path
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection.execute("CREATE TABLE x (id INTEGER)")
    ActiveRecord::Base.connection_pool.disconnect!
    assert File.exist?(path)

    task = build_task
    task.purge
    assert File.exist?(path)

    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    tables = ActiveRecord::Base.connection.tables
    refute_includes tables, "x"
  end
end
