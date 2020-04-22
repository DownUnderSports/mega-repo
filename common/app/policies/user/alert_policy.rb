# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/message_policy'

class User < ApplicationRecord
  class AlertPolicy < User::MessagePolicy
  end
end
