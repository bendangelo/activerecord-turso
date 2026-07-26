# frozen_string_literal: true

require_relative "../test_helper"

class BinaryColumnTest < Minitest::Test
  include ActiveRecordTursoTest

  class BinaryRecord < ActiveRecord::Base
  end

  def around
    cleanup_database
    ActiveRecord::Base.establish_connection(ActiveRecordTursoTest.base_config)
    ActiveRecord::Base.connection.create_table(:binary_records, force: true) do |t|
      t.binary :data
    end
    yield
  ensure
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    cleanup_database
  end

  def test_binary_roundtrip
    bytes = (0..255).to_a.pack("C*")
    record = BinaryRecord.create!(data: bytes)
    record.reload
    assert_equal bytes, record.data
  end

  def test_binary_nil
    record = BinaryRecord.create!(data: nil)
    record.reload
    assert_nil record.data
  end

  def test_binary_empty
    record = BinaryRecord.create!(data: "")
    record.reload
    assert_equal "", record.data
  end
end
