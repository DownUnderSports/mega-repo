# encoding: utf-8
# frozen_string_literal: true

module Travel
  class MyInfoController < ::Travel::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    # layout 'standalone'

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      @found_user = User[params[:id]]
      @title = "#{@found_user.basic_name} (#{@found_user.dus_id}) Travel Info"

      # return render pdf: @title, show_as_html: true, formats: :pdf
    end

    def flights
      @found_user = User[params[:id]]
      @title = "#{@found_user.basic_name} (#{@found_user.dus_id}) Flights"

      return render pdf: @title, show_as_html: true, formats: :pdf
    end

    def teammates
      @found_user = User[params[:id]]
      @title = "#{@found_user.basic_name} (#{@found_user.dus_id}) Flights"

      return render pdf: @title, show_as_html: true, formats: :pdf
    end
  end
end
