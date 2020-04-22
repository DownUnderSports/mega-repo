# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class RequestPolicy < ApplicationPolicy
    def update?
      user.staff&.check(:admin)
    end

    def create?
      user.staff&.check(:admin)
    end

    def destroy?
      user.staff&.check(:admin)
    end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(traveler_id: [user.traveler_id, *user.related_users.map(&:traveler_id)])
      end
    end
  end
end
