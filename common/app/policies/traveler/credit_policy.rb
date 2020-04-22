# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class CreditPolicy < ApplicationPolicy
    def update?
      is_credit_staff?
    end

    def create?
      is_credit_staff?
    end

    def destroy?
      is_credit_staff?
    end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(traveler_id: [user.traveler_id, *user.related_users.map(&:traveler_id)])
      end
    end

    private
      def is_credit_staff?
        !!(user.staff&.check(:credits))
      end
  end
end
