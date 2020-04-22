# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class RefundRequestPolicy < ApplicationPolicy
    def show?
      is_finance?
    end

    def destroy?
      is_finance?
    end

    private
      def is_finance?
        user_is_staff? && user.staff&.check(:finances)
      end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(user_id: [user.id, *user.relations.pluck(:related_user_id)])
      end
    end
  end
end
