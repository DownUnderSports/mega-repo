# encoding: utf-8
# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  before_perform do
    BetterRecord::Current.set(auto_worker, '127.0.0.1')
  end

  %w(path url).each do |cat|
    self.__send__ :define_method, :"rails_blob_#{cat}" do |*args|
      Rails.application.routes.url_helpers.__send__ :"rails_blob_#{cat}", *args
    end
  end

  def get_process
    return @process_id if @process_id.present?
    jid = provider_job_id.to_s
    processes = Sidekiq::ProcessSet.new

    if processes.size == 1
      @process_id = processes.first.identity
    elsif jid.present?
      processes.each do |pro|
        Sidekiq::Workers.new.each do |pro_id, thread_id, work|
          if pro_id == pro.identity
            if work['payload']['jid'] == jid
              @process_id = pro.identity
            end
          end
        rescue
          nil
        end
      end
      @process_id ||= processes.first.identity
    end
    @process_id.presence
  end

  def work_is_stopping?
    return false unless get_process
    is_stopping = false
    Sidekiq::ProcessSet.new.each do |process|
      if get_process == process.identity
        is_stopping = process.stopping?
        break
      end
    end
    return !!is_stopping
  end

  def work_is_stopping_lambda
    lambda { work_is_stopping? }
  end

end
