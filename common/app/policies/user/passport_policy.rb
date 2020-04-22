# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class PassportPolicy < ApplicationPolicy
    def show?
      user_is_staff?
    end

    def update?
      user_is_staff?
    end

    def create?
      update?
    end

    def destroy?
      user.staff&.check(:admin)
    end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(user_id: [user.id, *user.relations.pluck(:related_user_id)])
      end
    end
  end
end
