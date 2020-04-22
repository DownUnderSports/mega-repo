# encoding: utf-8
# frozen_string_literal: true

Dir["#{File.dirname(__FILE__)}/event_result/**/*.rb"].each {|f| require_dependency f }

# EventResult description
class EventResult < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  attribute :subject, :text
  attribute :description, :text
  attribute :email, :text

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :sport

  has_many :static_files, class_name: 'EventResult::StaticFile', inverse_of: :event_result

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  after_commit :send_email_if_needed, on: [ :update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

  private
    def send_email_if_needed
      if subject.present? && description.present?
        emails = []
        if email.present?
          emails = email.split(';')
        else
          Traveler.active.where(team: Team.where(sport_id: sport_id)).or(
            Traveler.active.where_exists(:buses, sport_id: sport_id)
          ).or(
            Traveler.active.where_exists(:competing_teams, sport_id: sport_id)
          ).split_batches_values do |t|
            t.user.athlete_and_parent_emails.each {|em| emails << em }
          end
          emails.uniq!
        end

        if emails.present?
          emails.in_groups_of(50).each do |gr|
            TravelMailer.with(sport: sport.id, emails: gr.select(&:present?), subject: subject, description: description).event_results.deliver_later
          end
        end
      end
    end

end
