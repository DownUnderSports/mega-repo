# encoding: utf-8
# frozen_string_literal: true

module API
  class UsersController < API::ApplicationController
    before_action :lookup_user

    def current
      check_user
      render json: current_user_hash(Boolean.parse(params[:minimal]))
    end

    def show
      return render json: {} unless @found_user

      if stale? @found_user
        render json: {
          fundraising_names: @found_user.fundraising_names,
          print_names: @found_user.print_names,
          payment_description: @found_user.payment_description,
          avatar: (@found_user.avatar.attached? ? url_for(@found_user.avatar.variant(resize: '500x500>', auto_orient: true)) : ''),
        }
      end
    end

    def valid
      return head @found_user.present? ? 204 : 410
    rescue
      return head 410
    end

    def traveling
      return head @found_user.traveler_payment? ? 204 : 410
    rescue NoMethodError
      return head 500
    end

    private
      def lookup_user
        if Boolean.parse(params[:by_hash])
          @found_user = User.find_by_dus_id_hash(params[:id])
        else
          @found_user = User.visible.get(params[:id])
        end
      end
  end
end
