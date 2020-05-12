# encoding: utf-8
# frozen_string_literal: true

class FundraisingIdeaPolicy < ApplicationPolicy
  def method_missing(m, *_, **_, &_)
    user_is_staff?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
