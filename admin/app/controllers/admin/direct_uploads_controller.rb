# encoding: utf-8
# frozen_string_literal: true

module Admin
  class DirectUploadsController < ::Admin::ApplicationController
    # == Modules ============================================================
    include Blobable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action do
      ActiveStorage::Current.host = request.base_url
    end

    # == Actions ============================================================
    def create
      authorize ActiveStorage::Blob
      create_blob
    end

    def event_result
      authorize EventResult.find(params[:event_id]), :static_file?
      create_blob
    end

    def passport
      authorize User.get(params[:id]), :passport_blob?
      create_blob
    end

    def legal_form
      authorize User.get(params[:id]), :legal_form_blob?
      create_blob
    end

    def assignment_of_benefits
      authorize User.get(params[:id]), :assignment_of_benefits_blob?
      create_blob
    end

    def flight_proofs
      authorize User.get(params[:id]), :flight_proofs_blob?
      create_blob
    end

    def insurance_proofs
      authorize User.get(params[:id]), :insurance_proofs_blob?
      create_blob
    end

    def eta_proofs
      authorize User.get(params[:id]), :eta_proofs_blob?
      create_blob
    end

    def incentive_deadlines
      authorize User.get(params[:id]), :incentive_deadlines_blob?
      create_blob
    end

    def fundraising_packet
      authorize User.get(params[:id]), :fundraising_packet_blob?
      create_blob
    end

    def fundraising_idea
      authorize FundraisingIdea
      create_blob
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
  end
end
