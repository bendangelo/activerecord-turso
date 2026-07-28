# frozen_string_literal: true

require_relative "../support/test_case"

class SQLite3ExplainTest < ActiveRecord::TursoConformanceTestCase
  def setup
    super
    ActiveRecord::Base.connection.create_table :authors, force: true do |t|
      t.string :name
    end
    ActiveRecord::Base.connection.create_table :posts, force: true do |t|
      t.integer :author_id
    end
    self.class.const_set(:Author, Class.new(ActiveRecord::Base) { self.table_name = "authors" })
    self.class.const_set(:Post, Class.new(ActiveRecord::Base) { self.table_name = "posts" })
  end

  def teardown
    super
    ActiveRecord::Base.connection.drop_table :authors, if_exists: true
    ActiveRecord::Base.connection.drop_table :posts, if_exists: true
  end

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain.inspect
    assert_match %r(EXPLAIN for: SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\? \[\["id", 1\]\]|1)), explain
    assert_match(/(SEARCH )?(TABLE )?authors USING (INTEGER )?PRIMARY KEY/, explain)
  end
end
