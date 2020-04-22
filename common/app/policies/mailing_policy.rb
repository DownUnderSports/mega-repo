# encoding: utf-8
# frozen_string_literal: true

class MailingPolicy < ApplicationPolicy
  def show?
    user_is_staff?
  end

  def update?
    user_is_staff? && record.staff_id == user.staff.id
  end

  def create?
    user_is_staff?
  end

  def destroy?
    user_is_staff?
  end

  class Scope < Scope
    def resolve
      user.is_staff? ? scope : scope.where(id: nil)
    end
  end
end
