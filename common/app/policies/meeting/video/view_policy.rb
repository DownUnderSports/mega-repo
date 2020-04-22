# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting/video'unless defined? Meeting::Video

class Meeting < ApplicationRecord
  class Video < ApplicationRecord
    class ViewPolicy < ApplicationPolicy
      def index?
        user_is_staff?
      end

      def show?
        user_is_staff?
      end

      def update?
        user_is_staff?
      end

      def create?
        user_is_staff?
      end

      def destroy?
        user_is_staff?
      end

      class Scope < Scope
        def resolve
          user.is_staff? ? scope : scope.where(id: nil)
        end
      end
    end
  end
end
