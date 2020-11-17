# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class GeneralReleasePolicy < ApplicationPolicy
    def index?
      user_is_staff?
    end

    class Scope < Scope
      def resolve
        scope
      end
    end
  end
end
