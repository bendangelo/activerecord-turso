# frozen_string_literal: true

require_relative "config"
require "minitest/autorun"
require "active_record"
require "activerecord-turso"
require "active_support/testing/method_call_assertions"
require "active_support/testing/stream"

module ActiveRecord
  class TursoConformanceTestCase < Minitest::Test
    include ActiveSupport::Testing::MethodCallAssertions
    include ActiveSupport::Testing::Stream

    self.fixture_paths = [FIXTURES_ROOT] if respond_to?(:fixture_paths=) && defined?(FIXTURES_ROOT)
    self.use_instantiated_fixtures = false if respond_to?(:use_instantiated_fixtures=)
    self.use_transactional_tests = false if respond_to?(:use_transactional_tests=)

    def setup
      super
      ActiveRecord::Base.establish_connection(ActiveRecordTursoConformanceTest.config)
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    end

    def teardown
      super
      ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.connection_pool
    end

  end
end
