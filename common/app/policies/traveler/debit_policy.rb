# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class DebitPolicy < ApplicationPolicy
    def airfare?
      is_debit_staff?
    end

    def update?
      is_debit_staff?
    end

    def create?
      is_debit_staff?
    end

    def destroy?
      is_debit_staff?
    end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(traveler_id: [user.traveler_id, *user.related_users.map(&:traveler_id)])
      end
    end

    private
      def is_debit_staff?
        !!(user.staff&.check(:debits))
      end
  end
end
