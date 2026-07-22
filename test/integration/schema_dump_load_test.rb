# frozen_string_literal: true

require_relative "../test_helper"

class DumpLoadUser < ActiveRecord::Base
  self.table_name = "dump_load_users"
end

class DumpLoadPost < ActiveRecord::Base
  self.table_name = "dump_load_posts"
  belongs_to :user, class_name: "DumpLoadUser"
end

class TestSchemaDumpLoad < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :dump_load_users, force: true do |t|
        t.string :email, null: false
        t.timestamps
      end

      create_table :dump_load_posts, force: true do |t|
        t.references :user, null: false
        t.string :title, null: false
        t.text :body
        t.boolean :published, default: false, null: false
        t.timestamps
      end

      add_index :dump_load_posts, :title, unique: true, name: "idx_dump_load_posts_title"
    end
  end

  def test_schema_dump_creates_valid_structure_sql
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
    dump = io.string

    assert_match(/create_table "dump_load_users"/, dump)
    assert_match(/create_table "dump_load_posts"/, dump)
    assert_match(/t\.index .*"title"/, dump)
  end

  def test_schema_load_recreates_tables_and_indexes
    original_dump = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, original_dump)

    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS dump_load_posts")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS dump_load_users")

    eval(original_dump.string)

    assert ActiveRecord::Base.connection.table_exists?(:dump_load_users)
    assert ActiveRecord::Base.connection.table_exists?(:dump_load_posts)
    assert ActiveRecord::Base.connection.index_exists?(:dump_load_posts, :title)

    user = DumpLoadUser.create!(email: "alice@example.com")
    post = DumpLoadPost.create!(user: user, title: "Hello", body: "World")
    assert_equal user.id, post.user_id
  end
end
