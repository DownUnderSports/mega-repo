# encoding: utf-8
# frozen_string_literal: true

class StatementsController < ApplicationController
  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================
  before_action :lookup_user

  # == Actions ============================================================
  def show
    respond_to do |format|
      format.html { fallback_index_html }
      format.pdf do
        render pdf: "statement_#{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
      end
    end
  end

  def payments
    respond_to do |format|
      format.html { fallback_index_html }
      format.pdf do
        @payments_only = true
        render pdf: "payments_as_of_#{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
      end
    end
  end

  # == Cleanup ============================================================

  # == Utilities ==========================================================
  private
    def lookup_user
      @user ||= User.find_by_dus_id_hash(params[:dus_id_hash])
      unless @user && @user.traveler
        request.format = :html
      end
      @user
    end

end
