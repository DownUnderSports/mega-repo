# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class UsersController < ::Aus::GetModelData::BaseCoachController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          users = User.
            where_exists(:traveler)

          if records_last_updated_at.present?
            users = users.
              joins(
                <<-SQL.cleanup_production
                  INNER JOIN (
                    SELECT
                      users.id,
                      MAX(sub_users.updated_at) AS max_updated_at
                    FROM
                      users
                    INNER JOIN user_relations
                      ON user_relations.user_id = users.id
                    INNER JOIN users sub_users
                      ON (
                        (sub_users.id = user_relations.related_user_id)
                        OR
                        (sub_users.id = users.id)
                      )
                    GROUP BY
                      users.id
                  ) updated_users
                    ON updated_users.id = users.id
                SQL
              ).
              where(
                'updated_users.max_updated_at > ?',
                records_last_updated_at
              )
          end


          Enumerator.new(users.size) do |y|
            users.each do |user|
              y << user.as_json.merge(
                bus_ids: user.traveler.buses.order(:id).pluck(:id),
                relations: (
                  user.relations.order(:relationship).map do |ur|
                    ur.related_user&.interest&.contactable? \
                      ? {
                          id: ur.related_user_id,
                          relationship: ur.relationship,
                          name: ur.related_user.basic_name,
                          gender: ur.related_user.gender,
                          phone: ur.related_user.ambassador_phone,
                          email: ur.related_user.ambassador_email,
                        } \
                      : {}
                  end
                ).select(&:present?)
              )
            end
          end
        end

        def get_deleted_records
          User::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end
    end
  end
end
