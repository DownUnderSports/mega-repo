# encoding: utf-8
# frozen_string_literal: true

class SportPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.where.not(abbr: 'SR')
    end
  end
end
