# encoding: utf-8
# frozen_string_literal: true

class PaymentPolicy < ApplicationPolicy
  def update?
    false
  end

  def create?
    true
  end

  def destroy?
    false
  end

  def pending?
    is_staff_type? :finances
  end

  def scope
    user_is_staff? ?
      super :
      super.where('created_at > ?', 48.hours.ago)
  end
end
