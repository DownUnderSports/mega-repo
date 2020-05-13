# encoding: utf-8
# frozen_string_literal: true

class FundraisingIdeaPolicy < ApplicationPolicy
  def index?
    !!user_is_staff?
  end

  def show?
    scope.where(id: record.id).exists?
  end

  def create?
    user_is_staff?
  end

  def new?
    user_is_staff?
  end

  def update?
    user_is_staff?
  end

  def edit?
    user_is_staff?
  end

  def destroy?
    user_is_staff?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
