# encoding: utf-8
# frozen_string_literal: true

module Admin
  class StatementsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: %i[ index ]

    # == Actions ============================================================
    def index
      return redirect_to next_user, status: 303
    end

    def show
      # unless params.key?(:as_html)
      #   Dir.mkdir(Rails.root.join('tmp', 'statements')) unless File.exist?(Rails.root.join('tmp', 'statements'))
      # end

      render pdf: "statement_#{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
      # **(!(params.key?(:as_html)) ? { save_to_file: Rails.root.join('tmp', 'statements', "statement-#{@user.dus_id}.pdf") } : { show_as_html: true })
    end

    def payments
      @payments_only = true
      render pdf: "payments_as_of_#{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def lookup_user
        return @user if @user

        @user = User.get(params[:id])
        if params.key?(:direct_print)
          next_user
          @direct_print = true
        end
      end

      def travelers
        Traveler.active.order(:user_id)
      end

      def next_user
        @next_user || get_next_user
      end

      def get_next_user
        @next_user = travelers.where('user_id > ?', @next_user&.id || @user&.id || 0).limit(1).take&.user
        return get_next_user if invalid_user
        @next_user &&= get_next_path
      end

      def invalid_user
        false
      end

      def get_next_path
        admin_statement_path(@next_user.dus_id, direct_print: 1, pp: :disable)
      end

  end
end
