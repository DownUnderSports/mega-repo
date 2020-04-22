# encoding: utf-8
# frozen_string_literal: true

module MailMessageCallBacks
  def deliver
    run_after_send(super)
  end

  def deliver!
    @email_was_delivered ||= run_after_send(super)
  end

  def after_send(&block)
    @after_send_actions ||= []
    @after_send_actions << block
  end

  def run_after_send(result)
    unless called
      (@after_send_actions || []).each do |block|
        begin
          block.call(result)
        rescue
          p $!.message
          p $!.backtrace
        end
      end
    end
    result
  end

  def called
    val = !!@called
    @called ||= true
    val
  end
end

Mail::Message.prepend MailMessageCallBacks
