# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/message_policy'

class User < ApplicationRecord
  class TransferExpectationPolicy < ApplicationPolicy
    def show?
      user_is_staff?
    end

    def update?
      user_is_staff?
    end

    def create?
      false
    end

    def destroy?
      false
    end

    class Scope < Scope
      def resolve
        user.is_staff? ? scope : scope.where(id: nil)
      end
    end
  end
end
