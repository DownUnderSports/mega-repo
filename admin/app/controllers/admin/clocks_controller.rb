# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ClocksController < Admin::AuthenticationController
    # == Constants ==========================================================
    ALLOWED_USERS = %w[ SAM-PSN SAR-ALO GAY-LEO ].freeze
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'internal'

    # == Pre/Post Flight Checks =============================================
    before_action :check_user
    before_action :set_all_clocks
    before_action :set_current_user_var

    # == Actions ============================================================
    def index
      return display_clocks
    end

    def show
      return redirect_to admin_clocks_path unless snooping_allowed?
      @user = User[params[:id]]
      return display_clocks
    rescue
      return redirect_to admin_clocks_path
    end

    def create
      clock = current_user.staff.add_clock!
      return redirect_to admin_clocks_path
    rescue
      return not_authorized([
        'Invalid',
        $!.message
      ], 422)
    end

    def edit
      return redirect_to admin_clocks_path unless snooping_allowed?
      @clock = Staff::Clock.find(params[:id])
      return redirect_to admin_clocks_path unless @clock
    rescue
      return redirect_to admin_clocks_path
    end

    def update
      redir_path = admin_clocks_path

      if snooping_allowed?
        clock = Staff::Clock.find(params[:id])
        clock.send :fix_time, Time.zone.parse(params[:time])
        redir_path = admin_clock_path(clock.staff.user.dus_id) if clock.staff != current_user.staff
      end

      return redirect_to redir_path
    rescue
      return redirect_to admin_clocks_path
    end

    def destroy
      redir_path = admin_clocks_path

      if snooping_allowed?
        clock = Staff::Clock.find(params[:id])
        clock.destroy
        redir_path = admin_clock_path(clock.staff.user.dus_id) if clock.staff != current_user.staff
      end

      return redirect_to redir_path
    rescue
      return redirect_to admin_clocks_path
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def set_current_user_var
        @current_user ||= current_user || check_user
      end

      def display_clocks
        respond_to do |format|
          format.html
          format.csv do
            render csv: "index", filename: "time_clock_for_#{(@user || current_user).full_name.gsub(/[^a-z0-9]/i, '-')}", with_time: true
          end
        end
      end

      def requesting_device_id
        @requesting_device_id = (session[:requesting_device_id] ||= SecureRandom.uuid)
      end

      def set_all_clocks
        @all_clocks = Boolean.parse(params[:all_clocks])
      end

      def snooping_allowed?
        current_user&.dus_id&.in? ALLOWED_USERS
      end
  end
end
