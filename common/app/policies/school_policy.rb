# encoding: utf-8
# frozen_string_literal: true

class SchoolPolicy < ApplicationPolicy
  def show?
    allowed?
  end

  def update?
    allowed?
  end

  def create?
    user_is_staff?
  end

  private
    def allowed?
      user_is_staff?
    end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
