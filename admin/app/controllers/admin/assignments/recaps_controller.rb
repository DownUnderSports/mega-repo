# encoding: utf-8
# frozen_string_literal: true
module Admin
  module Assignments
    class RecapsController < ::Admin::ApplicationController
      before_action :is_allowed?, only: [:index, :show]

      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            return render json: not_allowed unless is_allowed?

            users = User.staff.order(:first, :last, :id).
                         where_exists(:recaps)

            last_modified = users.try(:maximum, :updated_at)

            if stale? users, last_modified: last_modified
              return render json: {
                users: users.map do |user|
                    {
                      id: user.id,
                      last_recap: user.last_recap
                    }
                  end,
                version: last_modified
              }
            end
          end
        end
      end

      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            return render json: not_allowed unless is_allowed?

            user = User[params[:id]]

            return render json: no_recaps unless user.recaps.size > 0

            last_modified = user.recaps.try(:maximum, :updated_at)

            if stale? user.recaps, last_modified: last_modified
              return render json: { recaps: user.recaps.order(created_at: :desc) }
            end
          end
        end
      end

      def new
        return render json: {
          recap: use_last_recap? ? current_user.last_recap : current_user.recaps.new
        }
      end

      def create
        if find_recap_params[:id].present?
          recap = update_existing(find_recap_params[:id])
        else
          recap = current_user.recaps.create!(whitelisted_recap_params)
        end
        return render_success(recap.id)
      rescue
        return not_authorized($!.message, 422)
      end

      def update
        update_existing(params[:id])
        return render_success(recap.id)
      rescue
        return not_authorized($!.message, 422)
      end

      private
        def update_existing(id)
          recap = current_user.recaps.find_by(id: id)
          recap.update!(whitelisted_recap_params)
          recap
        end

        def use_last_recap?
          !!current_user.last_recap&.
                         created_at&.>=(Time.zone.now.midnight)
        end

        def find_recap_params
          params.require(:recap).permit(:id)
        end

        def whitelisted_recap_params
          params.require(:recap).permit(:log)
        end

        def is_allowed?
          !!current_user&.staff&.recaps
        end

        def not_allowed
          {
            errors: [ "Not allowed to view others' recaps" ]
          }
        end

        def no_recaps
          {
            errors: [ "No recaps submitted" ]
          }
        end
    end
  end
end
