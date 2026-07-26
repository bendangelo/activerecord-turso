# frozen_string_literal: true

require_relative "../test_helper"

class ExperimentalFeatureTest < Minitest::Test
  def around
    cleanup_database
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end

  def test_fts_index_method_works_when_enabled
    skip unless ActiveRecordTursoTest.experimental_features.include?("index_method")
    skip "FTS indexes are not supported in MVCC mode" if ActiveRecordTursoTest.journal_mode == "mvcc"

    connection = ActiveRecord::Base.connection
    connection.create_table(:feature_posts, force: true) do |t|
      t.string :title
      t.text :body
    end
    connection.add_fts_index :feature_posts, [:title, :body], tokenizer: :default

    indexes = connection.fts_indexes(:feature_posts)
    assert_includes indexes.map(&:to_s), "fts_feature_posts_title_body"
  end

  def test_generated_columns_work_when_enabled
    skip unless ActiveRecordTursoTest.experimental_features.include?("generated_columns")

    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL)
      CREATE TABLE generated_users (
        first_name TEXT,
        last_name TEXT,
        full_name TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL
      )
    SQL

    connection.execute("INSERT INTO generated_users (first_name, last_name) VALUES ('Ada', 'Lovelace')")
    row = connection.select_one("SELECT full_name FROM generated_users")
    assert_equal "Ada Lovelace", row["full_name"]
  end
end
