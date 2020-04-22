# encoding: utf-8
# frozen_string_literal: true

module Invite
  class FillInTheBlanksJob < ApplicationJob
    queue_as :default

    def perform(date, *args, **opts)
      Invite::Parser.fill_in_the_blanks(date, **opts.deep_symbolize_keys)
    end
  end
end
