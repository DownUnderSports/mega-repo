# encoding: utf-8
# frozen_string_literal: true

module MailMessageCallBacks
  def inform_observers
    run_after_send
    super
  end

  def after_send(&block)
    after_send_actions << block
  end

  def after_send_actions
    @after_send_actions ||= []
  end

  def run_after_send
    unless after_send_called
      after_send_actions.each do |block|
        begin
          block.call
        rescue
          Rails.logger.error $!.message
          Rails.logger.error $!.backtrace
        end
      end
    end
  end

  def after_send_called
    val = !!@after_send_called
    @after_send_called ||= true
    val
  end
end

Mail::Message.prepend MailMessageCallBacks
