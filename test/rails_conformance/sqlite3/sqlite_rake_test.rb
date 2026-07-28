# frozen_string_literal: true

require_relative "../support/test_case"
require "active_record/tasks/database_tasks"
require "pathname"

module ActiveRecord
  class TursoDBCharsetTest < ActiveRecord::TursoConformanceTestCase
    def setup
      super
      @database = ActiveRecordTursoConformanceTest.database_path
      @configuration = {
        "adapter"  => "turso",
        "database" => @database
      }
    end

    def teardown
      super
      FileUtils.rm_f(@database)
      FileUtils.rm_f("#{@database}-wal")
    end

    def test_db_retrieves_charset
      ActiveRecord::Base.stub(:lease_connection, Class.new { def encoding; "UTF-8"; end }.new) do
        assert_equal "UTF-8", ActiveRecord::Tasks::DatabaseTasks.charset(@configuration, "/rails/root")
      end
    end
  end
end
