# encoding: utf-8
# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    !!user_is_staff?
  end

  def show?
    scope.where(id: record.id).exists?
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  def scope
    Pundit.policy_scope!(user, record.model)
  end

  private
    def user_is_staff?
      user.present? && user.is_staff?
    end

    def user_is_admin?
      is_staff_type? :admin
    end

    def is_staff_type?(t)
      user_is_staff? && !!(user.staff&.check(t.to_sym))
    end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
