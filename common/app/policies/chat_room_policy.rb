# encoding: utf-8
# frozen_string_literal: true

class ChatRoomPolicy < ApplicationPolicy
  def index?
    user_is_staff?
  end

  def show?
    user_is_staff?
  end

  def destroy?
    user_is_admin?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
