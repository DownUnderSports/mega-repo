# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class BaseDebitPolicy < ApplicationPolicy
    def base?
      index?
    end

    def update?
      user.staff&.admin?
    end

    def create?
      user.staff&.admin?
    end

    def destroy?
      user.staff&.admin?
    end

    class Scope < Scope
      def resolve
        scope
      end
    end
  end
end
