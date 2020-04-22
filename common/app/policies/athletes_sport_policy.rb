# encoding: utf-8
# frozen_string_literal: true

class AthletesSportPolicy < ApplicationPolicy
  def show?
    allowed?
  end

  def update?
    allowed?
  end

  private
    def allowed?
      user_is_staff?
    end

  class Scope < Scope
    def resolve
      user.is_staff? ? scope : scope.where(Arel.sql("1=0"))
    end
  end
end
