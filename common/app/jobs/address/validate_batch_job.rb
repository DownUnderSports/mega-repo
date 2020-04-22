# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  class ValidateBatchJob < ApplicationJob
    queue_as :addresses

    def perform(*args)
      Address.process_batches
    end
  end
end
