# frozen_string_literal: true

require_relative "../support/test_case"
require_relative "../support/schema_dumping_helper"

class SQLite3VirtualColumnTest < ActiveRecord::TursoConformanceTestCase
  include SchemaDumpingHelper

  class VirtualColumn < ActiveRecord::Base
  end

  def setup
    super
    skip "generated_columns experimental feature not enabled" unless generated_columns_enabled?
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :virtual_columns, force: true do |t|
      t.string  :name
      t.virtual :upper_name, type: :string, as: "UPPER(name)", stored: true
    end
    VirtualColumn.create!(name: "Rails")
  end

  def teardown
    super
    @connection.drop_table :virtual_columns, if_exists: true
    VirtualColumn.reset_column_information
  end

  def test_stored_column
    column = VirtualColumn.columns_hash["upper_name"]
    assert_predicate column, :virtual?
    assert_predicate column, :virtual_stored?
    assert_equal "RAILS", VirtualColumn.take.upper_name
  end

  private
    def generated_columns_enabled?
      config = ActiveRecord::Base.connection_pool.db_config.configuration_hash
      Array(config[:experimental_features]).include?("generated_columns")
    end
end
