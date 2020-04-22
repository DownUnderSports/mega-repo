# encoding: utf-8
# frozen_string_literal: true

require_dependency 'import'

module Import
  class SendBadRecordsJob < ApplicationJob
    queue_as :importing

    def perform
      Import::Processor.bad_imports
    end
  end
end
