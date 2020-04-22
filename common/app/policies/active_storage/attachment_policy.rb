# encoding: utf-8
# frozen_string_literal: true

require 'active_storage'

module ActiveStorage
  class AttachmentPolicy < ApplicationPolicy
    def update?
      is_photo_staff?
    end

    def create?
      is_photo_staff?
    end

    def destroy?
      is_photo_staff?
    end

    class Scope < Scope
      def resolve
        scope
      end
    end

    private
      def is_photo_staff?
        # !!(user.staff&.check(:photos))
        user_is_staff?
      end
  end
end
