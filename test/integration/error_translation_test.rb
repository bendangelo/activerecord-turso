# frozen_string_literal: true

require_relative "../test_helper"

class UniqueRecord < ActiveRecord::Base
  self.table_name = "unique_records"
end

class ForeignRecord < ActiveRecord::Base
  self.table_name = "foreign_records"
end

class TestErrorTranslation < Minitest::Test
  def setup
    ActiveRecord::Schema.define do
      create_table :parents, force: true do |t|
        t.string :name
      end

      create_table :unique_records, force: true do |t|
        t.string :code, null: false
        t.index :code, unique: true
      end

      create_table :foreign_records, force: true do |t|
        t.references :parent, null: false, foreign_key: true
      end
    end
  end

  def test_unique_violation_raises_record_not_unique
    UniqueRecord.create!(code: "abc")
    assert_raises(ActiveRecord::RecordNotUnique) do
      UniqueRecord.create!(code: "abc")
    end
  end

  def test_foreign_key_violation_raises_invalid_foreign_key
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ForeignRecord.create!(parent_id: 9_999)
    end
  end

  def test_not_null_violation_raises_not_null_violation
    assert_raises(ActiveRecord::NotNullViolation) do
      ActiveRecord::Base.connection.execute("INSERT INTO unique_records (code) VALUES (NULL)")
    end
  end

  def test_busy_error_is_mapped_as_busy_error_not_deadlocked
    assert ActiveRecordTurso::BusyError < ActiveRecord::StatementInvalid
    assert ActiveRecordTurso::Error < ActiveRecord::StatementInvalid
  end
end
