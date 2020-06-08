# encoding: utf-8
# frozen_string_literal: true

module Admin
  class EmergencyContactsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'standalone'

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index ]

    # == Actions ============================================================
    def index
      expires_now

      respond_to do |format|
        format.html do
        end
        format.csv do
          render  csv: "all_travelers",
                  filename: "all_travelers",
                  with_time: true
        end
        format.any do
          return redirect_to admin_print_packets_path(format: :html), status: 303
        end
      end
    end

    def show
      expires_now

      return redirect_to admin_emergency_contacts_path(format: :html), status: 303 unless @sport = Sport[params[:id]]

      @title = get_file_name

      return render pdf: @title, show_as_html: true, formats: :pdf
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def get_file_name
        "emergency_contacts_#{@sport.abbr_gender}_#{Time.now.to_s(:db).gsub(/\s/, '_')}"
      end

  end
end
