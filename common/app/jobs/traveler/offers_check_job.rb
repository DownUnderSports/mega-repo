# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class OffersCheckJob < ApplicationJob
    queue_as :offers

    def perform(traveler_id)
      Traveler.find_by(id: traveler_id).offers.reload.each do |o|
        begin
          Traveler::Offer.find_by(id: o.id)&.run_check
        rescue
          ErrorMailer.with(
            message: $!.message,
            stack: $!.backtrace,
            additional: {
              job: 'Traveler::OffersCheckJob',
              traveler_id: traveler_id
            }
          ).ruby_error.deliver_later
        end
      end
    end
  end
end
