# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AmbassadorsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          ambassador_records = @found_user.ambassador_records.
            joins(:ambassador).
            references(:ambassador).
            joins(
              <<-SQL
                LEFT JOIN user_relations
                  ON user_relations.user_id = user_ambassadors.user_id
                  AND user_relations.related_user_id = user_ambassadors.ambassador_user_id
              SQL
            ).
            order('users.first', 'users.last').
            select(:id, :user_id, :ambassador_user_id, :types_array, "user_relations.relationship", "users.dus_id", "users.first", "users.last", "users.category_type")

          last_modified = @found_user.ambassador_records.try(:maximum, :updated_at)

          if stale? ambassador_records, last_modified: last_modified
            return render json: {
              ambassador_records: ambassador_records.map do |rel|
                  ambassador = User.new(id: rel.ambassador_user_id, dus_id: rel.dus_id, first: rel.first, last: rel.last, category_type: rel.category_type)
                  {
                    id: rel.id,
                    user_id: rel.user_id,
                    ambassador_user_id: rel.ambassador_user_id,
                    types_array: rel.types_array,
                    dus_id: ambassador.dus_id,
                    first: ambassador.first,
                    last: ambassador.last,
                    relationship: rel.relationship,
                    category: ambassador.category_title
                  }
                end,
              version: last_update
            }
          end
        end
      end
    end

    def update
      successful, errors, rel = nil

      begin
        rel = @found_user.ambassador_records.find_by(id: params[:id])
        rel.update!(whitelisted_ambassador_params)
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def create
      successful, errors, rel = nil, ambassador = nil, destroy_on_error = false

      begin
        rel = @found_user.ambassador_records.create!(whitelisted_ambassador_params)
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def destroy
      successful, errors, rel = nil

      begin
        rel = @found_user.ambassador_records.find_by(id: params[:id])
        rel.destroy!
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def last_update
        begin
          return nil unless @found_user.ambassador_records.count > 0
          @found_user.
            ambassador_records.
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.
            utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end

      def whitelisted_ambassador_params
        return @whitelisted_ambassador_params if @whitelisted_ambassador_params.present?
        @whitelisted_ambassador_params =
          params.
            require(:ambassador).
            permit(:ambassador_user_id, types_array: []).
            to_h.
            with_indifferent_access

        if ambassador = params[:dus_id].presence && User.get(params[:dus_id])
          @whitelisted_ambassador_params[:ambassador_user_id] = ambassador.id
        end
        @whitelisted_ambassador_params
      end
  end
end
