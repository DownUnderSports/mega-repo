# encoding: utf-8
# frozen_string_literal: true

module Admin
  class RelationsController < ::Admin::ApplicationController
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
          relations = @found_user.relations.
            joins(:related_user).
            references(:related_user).
            order('users.first', 'users.last')

          last_modified = relations.try(:maximum, %q(GREATEST(user_relations.updated_at, users.updated_at)))

          if stale? relations, last_modified: last_modified 
            return render json: {
              relations: relations.map do |rel|
                  {
                    id: rel.id,
                    user_id: rel.user_id,
                    related_user_id: rel.related_user_id,
                    relationship: rel.relationship,
                    first: rel.related_user.first,
                    last: rel.related_user.last,
                    category: rel.related_user.category_title,
                    traveling: !!rel.related_user.traveler,
                    canceled: rel.related_user.traveler&.cancel_date.present?
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
        rel = @found_user.relations.find_by(id: params[:id])
        rel.related_user.update!(whitelisted_user_params)
        if params[:user][:relationship].present? && rel.relationship != params[:user][:relationship]
          rel.update!(relationship: params[:user][:relationship])
        end
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def create
      successful, errors, rel = nil, related_user = nil, destroy_on_error = false

      begin
        raise "Validation failed: Relationship type must exist" unless params[:user][:relationship].present?

        related_user = params[:dus_id].presence && User.get(params[:dus_id])
        unless related_user
          destroy_on_error = true
          related_user = User.create!(whitelisted_user_params)
        end

        rel = @found_user.relations.create!(
          relationship: params[:user][:relationship].presence,
          related_user: related_user
        )
        successful = true
      rescue
        begin
          destroy_on_error && related_user&.id && related_user.destroy
        rescue
        end
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
          return nil unless @found_user.relations.count > 0
          [
            @found_user.relations.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first,
            @found_user.related_users.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first
          ].max.utc.iso8601
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
  end
end
