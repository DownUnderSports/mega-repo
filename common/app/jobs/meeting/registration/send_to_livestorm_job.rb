# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting/registration'

class Meeting < ApplicationRecord
  class Registration < ApplicationRecord
    class SendToLivestormJob < ApplicationJob
      queue_as :default

      def perform(meeting_id)
        Meeting::Registration.send_to_livestorm(meeting_id)
      end
    end
  end
end
