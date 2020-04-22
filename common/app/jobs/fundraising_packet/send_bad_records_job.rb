# encoding: utf-8
# frozen_string_literal: true

require_dependency 'fundraising_packet'

module FundraisingPacket
  class SendBadRecordsJob < ApplicationJob
    queue_as :importing

    def perform
      FundraisingPacket::Processor.bad_packets
    end
  end
end
