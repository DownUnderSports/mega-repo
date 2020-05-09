# encoding: utf-8
# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    allowed?
  end

  def update?
    allowed?
  end

  def create?
    user_is_staff?
  end

  def destroy?
    user_is_staff? && !record.requested_infokit?
  end

  def cancel?
    user.staff&.check(:debits)
  end

  def addresses_available?
    user_is_staff?
  end

  def infokit?
    user_is_staff?
  end

  def travel_preparation?
    user_is_staff?
  end

  def travel_preparations?
    travel_preparation?
  end

  def main_address?
    allowed?
  end

  def get_file?
    user_is_staff?
  end

  def get_file_value?
    user_is_staff?
  end

  def passport_blob?
    !record.passport&.image&.attached?
  end

  def legal_form_blob?
    !record.signed_terms.attached?
  end

  def assignment_of_benefits_blob?
    !record.assignment_of_benefits.attached?
  end

  def incentive_deadlines_blob?
    !record.incentive_deadlines.attached?
  end

  def fundraising_packet_blob?
    user_is_staff? && !record.fundraising_packet.attached?
  end

  def insurance_proofs_blob?
    user_is_staff?
  end

  def flight_proofs_blob?
    user_is_staff?
  end

  def eta_proofs_blob?
    !!record.passport && user_is_staff?
  end

  def eta_values?
    user_is_staff?
  end

  def extra_processing?
    user_is_staff?
  end

  def create_transfer?
    user.staff&.check(:finances)
  end

  def admin?
    user_is_admin?
  end

  def on_the_fence?
    user_is_staff? && user.dus_id.in?(%[ DAN-IEL GAY-LEO SAR-ALO SAM-PSN ])
  end

  def selected_cancel?
    corona_emails?
  end

  def unselected_cancel?
    corona_emails?
  end

  private
    def corona_emails?
      user_is_staff? &&
      user.dus_id.in?(%[ DAN-IEL GAY-LEO KAR-ENJ SAR-ALO SAM-PSN SHR-RIE ])
    end

    def allowed?
      user_is_staff? || [user.id, *user.relations.pluck(:related_user_id)].include?(record.id)
    end

  class Scope < Scope
    def resolve
      user.is_staff? ? scope : scope.where(id: [user.id, *user.relations.pluck(:related_user_id)])
    end
  end
end
