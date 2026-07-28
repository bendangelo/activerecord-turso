# frozen_string_literal: true

require_relative "../support/test_case"
require_relative "../support/ddl_helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterTest < ActiveRecord::TursoConformanceTestCase
      include DdlHelper

      class DualEncoding < ActiveRecord::Base
      end

      class Barcode < ActiveRecord::Base
      end

      class BarcodeCustomPk < ActiveRecord::Base
        self.primary_key = "code"
      end

      class BarcodeCpk < ActiveRecord::Base
        self.primary_key = ["region", "code"]
      end

      def setup
        super
        @conn = ActiveRecord::ConnectionAdapters::TursoAdapter.new(
          ActiveRecordTursoConformanceTest.config
        )
      end

      def teardown
        @conn.disconnect! if @conn
        super
      end

      def test_connect
        assert @conn, "should have connection"
      end

      def test_encoding
        assert_equal "UTF-8", @conn.encoding
      end

      def test_exec_no_binds
        with_example_table @conn, "ex" do
          result = @conn.exec_query("SELECT id, number FROM ex")
          assert_equal 0, result.rows.length
          assert_equal 2, result.columns.length
          assert_equal %w{ id number }, result.columns

          @conn.exec_query("INSERT INTO ex (number) VALUES (1)")
          result = @conn.exec_query("SELECT id, number FROM ex")
          assert_equal 1, result.rows.length
          assert_equal [[1, 1]], result.rows
        end
      end

      def test_exec_query_with_binds
        with_example_table @conn, "ex" do
          @conn.exec_query("INSERT INTO ex (number) VALUES (1)")
          result = @conn.exec_query(
            "SELECT id, number FROM ex WHERE id = ?", nil,
            [Relation::QueryAttribute.new(nil, 1, Type::Value.new)]
          )
          assert_equal 1, result.rows.length
          assert_equal [[1, 1]], result.rows
        end
      end

      def test_transaction
        with_example_table @conn, "ex" do
          count_sql = "select count(*) from ex"

          @conn.begin_db_transaction
          @conn.execute("INSERT INTO ex (number) VALUES (10)")
          assert_equal 1, @conn.select_rows(count_sql).first.first
          @conn.rollback_db_transaction
          assert_equal 0, @conn.select_rows(count_sql).first.first
        end
      end

      def test_tables
        with_example_table @conn, "ex" do
          assert_equal %w{ ex }, @conn.tables
          with_example_table @conn, "people", "id integer PRIMARY KEY AUTOINCREMENT, number integer" do
            assert_equal %w{ ex people }.sort, @conn.tables.sort
          end
        end
      end

      def test_columns
        with_example_table @conn, "ex" do
          columns = @conn.columns("ex").sort_by(&:name)
          assert_equal 2, columns.length
          assert_equal %w{ id number }.sort, columns.map(&:name)
          assert_equal [nil, nil], columns.map(&:default)
          assert_equal [true, true], columns.map(&:null)
        end
      end

      def test_columns_with_default
        with_example_table @conn, "ex", "id integer PRIMARY KEY AUTOINCREMENT, number integer default 10" do
          column = @conn.columns("ex").find { |x| x.name == "number" }
          assert_equal 10, column.default
        end
      end

      def test_columns_with_not_null
        with_example_table @conn, "ex", "id integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
          column = @conn.columns("ex").find { |x| x.name == "number" }
          refute column.null, "column should not be null"
        end
      end

      def test_add_column_with_not_null
        with_example_table @conn, "ex", "id integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
          @conn.add_column :ex, :name, :string, null: false
          column = @conn.columns("ex").find { |x| x.name == "name" }
          refute column.null, "column should not be null"
        end
      end

      def test_no_indexes
        assert_equal [], @conn.indexes("items")
      end

      def test_index
        with_example_table @conn, "ex" do
          @conn.add_index "ex", "id", unique: true, name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }

          assert_equal "ex", index.table
          assert index.unique, "index is unique"
          assert_equal ["id"], index.columns
        end
      end

      def test_non_unique_index
        with_example_table @conn, "ex" do
          @conn.add_index "ex", "id", name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }
          refute index.unique, "index is not unique"
        end
      end

      def test_compound_index
        with_example_table @conn, "ex" do
          @conn.add_index "ex", %w{ id number }, name: "fun"
          index = @conn.indexes("ex").find { |idx| idx.name == "fun" }
          assert_equal %w{ id number }.sort, index.columns.sort
        end
      end

      def test_primary_key
        with_example_table @conn, "ex" do
          assert_equal "id", @conn.primary_key("ex")
          with_example_table @conn, "foos", "internet integer PRIMARY KEY AUTOINCREMENT, number integer not null" do
            assert_equal "internet", @conn.primary_key("foos")
          end
        end
      end

      def test_no_primary_key
        with_example_table @conn, "ex", "number integer not null" do
          assert_nil @conn.primary_key("ex")
        end
      end

      def test_supports_extensions
        refute @conn.supports_extensions?, "does not support extensions"
      end

      def test_respond_to_enable_extension
        assert_respond_to @conn, :enable_extension
      end

      def test_respond_to_disable_extension
        assert_respond_to @conn, :disable_extension
      end

      def test_db_is_not_readonly_when_readonly_option_is_false
        skip "Turso adapter does not support readonly mode"
        conn = ActiveRecord::ConnectionAdapters::TursoAdapter.new(
          ActiveRecordTursoConformanceTest.config.merge(readonly: false)
        )
        conn.connect!
        refute conn.instance_variable_get(:@readonly)
      ensure
        conn.disconnect! if conn
      end

      def test_db_is_readonly_when_readonly_option_is_true
        skip "Turso adapter does not support readonly mode"
        conn = ActiveRecord::ConnectionAdapters::TursoAdapter.new(
          ActiveRecordTursoConformanceTest.config.merge(readonly: true)
        )
        conn.connect!
        assert conn.instance_variable_get(:@readonly)
      ensure
        conn.disconnect! if conn
      end

      def test_copy_table_with_existing_records_have_custom_primary_key
        connection = BarcodeCustomPk.lease_connection
        connection.create_table(:barcode_custom_pks, primary_key: "code", id: :string, limit: 42, force: true) do |t|
          t.text :other_attr
        end
        code = "214fe0c2-dd47-46df-b53b-66090b3c1d40"
        BarcodeCustomPk.create!(code: code, other_attr: "xxx")

        connection.remove_column("barcode_custom_pks", "other_attr")

        assert_equal code, BarcodeCustomPk.first.id
      ensure
        BarcodeCustomPk.reset_column_information
        ActiveRecord::Base.connection.drop_table(:barcode_custom_pks, if_exists: true)
      end
    end
  end
end
