# encoding: utf-8
# frozen_string_literal: true

namespace :uploads do
  desc 'Delete Visited Assignments for the day'
  task clear_invalid: :environment do
    ClearInvalidUploadsJob.perform_later
  end
end
