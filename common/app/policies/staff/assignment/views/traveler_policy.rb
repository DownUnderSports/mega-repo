# encoding: utf-8
# frozen_string_literal: true

Staff::Assignment::Views

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    module Views
      class TravelerPolicy < RespondPolicy
        class Scope < Scope
          def resolve
            scope.all
          end
        end
      end
    end
  end
end
