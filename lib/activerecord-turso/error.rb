# frozen_string_literal: true

module ActiveRecordTurso
  class Error < ActiveRecord::StatementInvalid; end
  class BusyError < Error; end
end
