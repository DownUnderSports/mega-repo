# encoding: utf-8
# frozen_string_literal: true

namespace :report do
  desc 'Email Respond totals to ISSI-USA'
  task responds: :environment do
    ReportMailer.respond_totals.deliver_now
  end
end
