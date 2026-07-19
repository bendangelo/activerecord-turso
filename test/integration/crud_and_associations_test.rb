# frozen_string_literal: true

require_relative "../test_helper"

class User < ActiveRecord::Base
  has_many :posts, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class Tag < ActiveRecord::Base
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings
end

class Tagging < ActiveRecord::Base
  belongs_to :post
  belongs_to :tag
end

class TestCrudAndAssociations < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :users, force: true do |t|
        t.string :name, null: false
        t.timestamps
      end

      create_table :posts, force: true do |t|
        t.references :user, null: false, foreign_key: true
        t.string :title, null: false
        t.text :body
        t.timestamps
      end

      create_table :comments, force: true do |t|
        t.references :post, null: false, foreign_key: true
        t.string :body, null: false
        t.timestamps
      end

      create_table :tags, force: true do |t|
        t.string :name, null: false
      end

      create_table :taggings, force: true do |t|
        t.references :post, null: false, foreign_key: true
        t.references :tag, null: false, foreign_key: true
      end
    end
  end

  def test_crud
    user = User.create!(name: "Alice")
    assert_equal "Alice", user.reload.name

    user.update!(name: "Bob")
    assert_equal "Bob", user.reload.name

    user.destroy!
    assert_nil User.find_by(id: user.id)
  end

  def test_associations_and_cascade_delete
    user = User.create!(name: "Alice")
    post = user.posts.create!(title: "Hello", body: "World")
    comment = post.comments.create!(body: "Nice post")
    tag = Tag.create!(name: "ruby")
    post.tags << tag

    assert_equal [post], user.posts.to_a
    assert_equal [comment], post.comments.to_a
    assert_equal [tag], post.tags.to_a

    user.destroy!
    assert_empty Post.where(id: post.id)
    assert_empty Comment.where(id: comment.id)
    assert_empty Tagging.where(post_id: post.id)
  end

  def test_eager_loading
    user = User.create!(name: "Alice")
    3.times { |i| user.posts.create!(title: "Post #{i}") }

    users = User.includes(:posts).to_a
    assert_equal 1, users.size
    assert_equal 3, users.first.posts.size
  end
end
