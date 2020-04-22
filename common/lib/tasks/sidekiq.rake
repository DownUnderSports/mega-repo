# encoding: utf-8
# frozen_string_literal: true

namespace :sidekiq do
  desc 'Push infokit followup emails to end of queue'
  task requeue_followup_emails: :environment do
    require 'sidekiq/api'

    sq = Sidekiq::Queue.new("mailers")
    sq.each do |j|
      args = j.args[0] || {}
      if args['arguments'] && (args['arguments'][0] == "InfokitMailer") && (args['arguments'][1] == "send_followup_details")
        j.delete
        InfokitMailer.send_followup_details(*(args['arguments'][3..-1])).deliver_later(wait_until: 10.seconds.from_now, queue: :mass_mailer)
      end
    end

    Sidekiq::ScheduledSet.new.scan("*mailers*InfokitMailer*send_followup_details*").select do |job|
      args = job.args[0] || {}
      if args['job_class'] == 'ActionMailer::DeliveryJob' && args['queue_name'] == "mailers"
        arguments = args['arguments']
        if arguments[0] == "InfokitMailer" && arguments[1] == "send_followup_details"
          InfokitMailer.send_followup_details(*arguments[3..-1]).deliver_later(wait_until: job.at.in_time_zone, queue: :mass_mailer)
          true
        else
          false
        end
      else
        false
      end
    end.each(&:delete)
  end
end
