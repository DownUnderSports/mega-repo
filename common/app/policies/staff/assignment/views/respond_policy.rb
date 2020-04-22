# encoding: utf-8
# frozen_string_literal: true

Staff::Assignment::Views

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    module Views
      class RespondPolicy < ApplicationPolicy
        def show?
          allowed?
        end

        def update?
          allowed?
        end

        def create?
          allowed?
        end

        def reassign?
          is_staff_type? :management
        end

        def destroy?
          allowed?
        end

        private
          def allowed?
            user_is_staff?
          end

        class Scope < Scope
          def resolve
            scope.all
          end
        end
      end
    end
  end
end
