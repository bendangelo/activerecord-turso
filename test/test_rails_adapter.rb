# frozen_string_literal: true

require_relative "test_helper"

class TestRailsAdapter < Minitest::Test
  def setup
    ActiveRecord::Base.establish_connection(
      adapter: "turso",
      database: ":memory:"
    )

    ActiveRecord::Schema.define do
      create_table :posts do |t|
        t.string :title
        t.text :body
        t.boolean :published
        t.timestamps
      end
    end

    @klass = Class.new(ActiveRecord::Base) do
      self.table_name = "posts"
    end
  end

  def test_create_and_find
    post = @klass.create!(title: "Hello", body: "World", published: true)
    found = @klass.find(post.id)
    assert_equal "Hello", found.title
    assert_equal true, found.published
  end

  def test_transaction_rollback
    @klass.transaction do
      @klass.create!(title: "Rollback")
      raise ActiveRecord::Rollback
    end
    assert_equal 0, @klass.count
  end

  def test_update_and_delete
    post = @klass.create!(title: "First", published: false)
    post.update!(title: "Updated")
    assert_equal "Updated", post.reload.title
    post.destroy
    assert_equal 0, @klass.count
  end
end
