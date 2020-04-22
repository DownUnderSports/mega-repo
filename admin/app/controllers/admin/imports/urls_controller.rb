# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Imports
    class UrlsController < ::Admin::ApplicationController
      layout 'internal'

      URL_REG = /^\w+\:\/\/staff\.downundersports\.com\/athletes\/(\d+)\/edit/
      COACH_REG = /^\w+\:\/\/staff\.downundersports\.com\/coaches\/(\d+)\/edit/
      OFFICIAL_REG = /^\w+\:\/\/staff\.downundersports\.com\/officials\/(\d+)\/edit/

      def show
        if params[:errors].present?
          @errors = params[:errors] rescue "Unknown Error"
        elsif params[:user].present?
          @user = User[params[:user]]
          @next_year = Boolean.parse(params[:selected_next_year])
          @infokit = Boolean.parse(params[:selected_infokit])
        end
      end

      def create
        return create_coach if params[:url].to_s =~ COACH_REG
        return create_official if params[:url].to_s =~ OFFICIAL_REG

        user = athlete_id = infokit = next_year = errors = nil
        ActiveRecord::Base.transaction do
          raise "Invalid URL" unless params[:url].to_s =~ URL_REG
          athlete_id = params[:url][URL_REG, 1]
          user = get_athlete_user(athlete_id)
          user.save!
          if Boolean.parse(params[:next_year])
            next_year = true
            puts "Marking #{athlete_id} as Next Year"
            user.update!(interest_id: Interest::NextYear.id)
          else
            user.update!(responded_at: Time.zone.now) unless user.responded_at.present?
          end
        end
        if Boolean.parse(params[:infokit])
          puts "Sending Infokit to #{athlete_id}"
          infokit, errors = infokit_mail_and_emails user
        end
        return redirect_to admin_imports_url_path(user: user.id, selected_next_year: next_year ? 1 : 0, selected_infokit: infokit ? 1 : 0, errors: errors ? encode_uri_component(errors) : nil)
      rescue
        errors = ([ $!.message ] + $!.backtrace).join("\n")
        puts errors
        encoded_errors = encode_uri_component(errors)
        if encoded_errors.size > 7_499
          trail = encode_uri_component "\n..."
          encoded_errors = encoded_errors[0..7_499].split("%")[0..-2].join('%') + trail
        end
        return redirect_to "#{admin_imports_url_path}?errors=#{encoded_errors}"
      end

      def create_coach
        user = coach_id = errors = nil
        ActiveRecord::Base.transaction do
          raise "Invalid URL" unless params[:url].to_s =~ COACH_REG
          coach_id = params[:url][COACH_REG, 1]
          user = get_coach_user(coach_id)
          user.save!
        end
        return redirect_to admin_imports_url_path(user: user.id, errors: errors ? encode_uri_component(errors) : nil)
      end

      def create_official
        user = official_id = errors = nil
        ActiveRecord::Base.transaction do
          raise "Invalid URL" unless params[:url].to_s =~ OFFICIAL_REG
          official_id = params[:url][COACH_REG, 1]
          user = get_official_user(official_id)
          user.save!
        end
        return redirect_to admin_imports_url_path(user: user.id, errors: errors ? encode_uri_component(errors) : nil)
      end

      private
        def get_athlete_user(athlete_id)
          attributes = fetch_from_legacy_data("/athletes/#{athlete_id}/to_new_db").deep_symbolize_keys
          raise "User Not Found" unless attributes.present?
          build_user(attributes)
        end

        def get_coach_user(coach_id)
          attributes = fetch_from_legacy_data("/coaches/#{coach_id}/to_new_db").deep_symbolize_keys
          raise "User Not Found" unless attributes.present?
          build_user(attributes)
        end

        def get_official_user(official_id)
          attributes = fetch_from_legacy_data("/officials/#{official_id}/to_new_db").deep_symbolize_keys
          raise "User Not Found" unless attributes.present?
          build_user(attributes)
        end

        def build_user(attributes)
          category_type = attributes.delete(:category_type)
          category_attributes = attributes.delete(:category_attributes)
          attributes[:category] = get_category(category_type, category_attributes)
          attributes[:relations_attributes]&.map! do |rel_attrs|
            rel_attrs[:related_user] = build_user(rel_attrs[:related_user])
            rel_attrs
          end
          User.new(attributes)
        end

        def get_category(category_type, attributes)
          case category_type
          when /athlete/i
            build_athlete(attributes)
          when /coach/i
            build_coach(attributes)
          when /official/i
            build_official(attributes)
          else
            nil
          end
        end

        def build_athlete(attributes)
          school_pid = attributes.delete(:school_pid)
          attributes[:school] = school_pid.presence && School.find_by(pid: school_pid)
          attributes[:sport] = Sport.find_by(abbr_gender: attributes[:sport])
          attributes[:athletes_sports_attributes].each do |attr|
            attr[:sport] = Sport.find_by(abbr_gender: attr[:sport])
          end
          Athlete.new(attributes.deep_symbolize_keys)
        end

        def build_coach(attributes)
          school_pid = attributes.delete(:school_pid)
          txfr_school_id = attributes.delete(:txfr_school_id)&.to_i
          school_pid = attributes.delete(:school_pid)
          attributes[:school] = school_pid.presence && School.find_by(pid: school_pid)
          attributes[:school] ||= txfr_school_id.presence && School.import_from_transfer_id(txfr_school_id)
          attributes[:sport] = Sport.find_by(abbr_gender: attributes[:sport])
          Coach.new(attributes.deep_symbolize_keys)
        end

        def build_official(attributes)
          attributes[:state] = State.find_by(abbr: attributes[:state])
          attributes[:sport] = Sport.find_by(abbr_gender: attributes[:sport])
          Coach.new(attributes.deep_symbolize_keys)
        end
    end
  end
end
