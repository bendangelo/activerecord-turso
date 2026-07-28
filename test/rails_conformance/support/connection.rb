# frozen_string_literal: true

require_relative "config"
require "active_support/logger"

module ActiveRecordTursoConformanceTest
  def self.connect
    ActiveRecord::Base.logger = nil
    ActiveRecord::Base.establish_connection(config)
  end
end
