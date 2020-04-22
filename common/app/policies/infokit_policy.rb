# encoding: utf-8
# frozen_string_literal: true

class InfokitPolicy < ApplicationPolicy
  def valid?
    !!record && !!(record.is_athlete? && !(record.requested_infokit?))
  end

  def create?
    !record || valid?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
