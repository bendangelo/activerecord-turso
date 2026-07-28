# frozen_string_literal: true

require_relative "../support/test_case"

class SQLite3BindParameterTest < ActiveRecord::TursoConformanceTestCase
  class Post < ActiveRecord::Base
    self.table_name = "conformance_posts"
  end

  def setup
    super
    ActiveRecord::Base.connection.create_table :conformance_posts, force: true do |t|
      t.string :title
    end
    Post.create!(title: "Welcome to the weblog")
  end

  def teardown
    super
    ActiveRecord::Base.connection.drop_table :conformance_posts, if_exists: true
  end

  def test_where_with_string_for_string_column_using_bind_parameters
    relation = Post.where("title = ?", "Welcome to the weblog")
    assert_equal 1, relation.count
  end

  def test_where_with_integer_for_string_column_using_bind_parameters
    relation = Post.where("title = ?", 0)
    assert_empty relation.to_a
  end
end
