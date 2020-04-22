# encoding: utf-8
# frozen_string_literal: true

class EventResultPolicy < ApplicationPolicy
  def show?
    true
  end

  def update?
    user_is_staff?
  end

  def create?
    user_is_staff?
  end

  def destroy?
    user_is_staff?
  end

  def static_file?
    user_is_staff?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
