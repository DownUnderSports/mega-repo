# encoding: utf-8
# frozen_string_literal: true

require_dependency 'fundraising_packet'

module FundraisingPacket
  class ProcessFileJob < ApplicationJob
    queue_as :importing

    def perform(**opts)
      begin
        FundraisingPacket::Processor.run **opts
      rescue
        puts $!.message
        puts $!.backtrace
        raise
      end
    end
  end
end
