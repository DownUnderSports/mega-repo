# encoding: utf-8
# frozen_string_literal: true

require_dependency 'import'

module Import
  class ProcessFileJob < ApplicationJob
    queue_as :importing

    def perform(**opts)
      Import::Processor.run **(opts.merge(work_is_stopping: work_is_stopping_lambda))
    end
  end
end
