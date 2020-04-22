# encoding: utf-8
# frozen_string_literal: true

require_dependency 'invite'

module Invite
  class MarkDatesJob < ApplicationJob
    queue_as :importing

    def perform(**opts)
      Invite::Processor.run **(opts.merge(work_is_stopping: work_is_stopping_lambda))
    end
  end
end
