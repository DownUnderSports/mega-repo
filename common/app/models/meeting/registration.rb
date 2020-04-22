# encoding: utf-8
# frozen_string_literal: true
class Meeting < ApplicationRecord
  class Registration < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.meeting_registrations"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :meeting
    belongs_to :user
    belongs_to :athlete, optional: true

    delegate :start_time, to: :meeting

    # == Validations ==========================================================
    validates_uniqueness_of :meeting_id, scope: :user_id

    # == Scopes ===============================================================
    default_scope { default_order(:meeting_id, :id) }

    scope :attended, -> { where(attended: true) }
    scope :missed, -> { where(attended: false) }

    # == Callbacks ============================================================
    after_commit :run_checks, on: %i[ create update ]

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.send_to_livestorm(meeting_id)
      meeting = Meeting.find(meeting_id)
      if ((Time.zone.now + 1.hour) > meeting.start_time) && (Time.zone.now < (meeting.start_time + 30.minutes))
        where(meeting_id: meeting_id).each do |r|
          r.run_email_checks
          sleep 5
        end
      end
    end

    def self.send_upcoming_reminders(meeting_id)
      meeting = Meeting.find(meeting_id)
      where(meeting_id: meeting_id).each do |r|
        if r.user.email.present? && !(
          r.user.contact_histories.
          where('created_at > ?', Time.zone.now.midnight).
          find_by(message: [r.confirmation_message, r.upcoming_message])
        )
          r.meeting_upcoming_email
          sleep 5
        end
      end
    end

    # == Boolean Methods ======================================================
    def allowed_offers?
      !!(
        meeting.offer.present? &&
        (
          !user.traveler ||
          (
            user.traveler.credits.
            where(name: meeting.offer_exceptions_array).count == 0
          )
        ) &&
        (
          user.offers.
          where(name: meeting.offer_exceptions_array).
          count == 0
        )
      )
    end

    # == Instance Methods =====================================================

    def livestorm_message
      "Sent meeting registration email for meeting @ #{meeting.start_time.to_s(:long_ordinal)} to #{user.email}"
    end

    def confirmation_message
      "Sent confirmation email for meeting @ #{meeting.start_time.to_s(:long_ordinal)} to #{user.email}"
    end

    def upcoming_message
      "Sent meeting reminder email for meeting @ #{meeting.start_time.to_s(:long_ordinal)} to #{user.email}"
    end

    def run_checks
      run_email_checks unless attended
      run_offers_check if attended
    end

    def run_email_checks
      if user.email.present?
        if !(user.contact_histories.find_by(message: livestorm_message))
          if (Time.zone.now + 1.hour) > meeting.start_time
            livestorm_registration if Time.zone.now < (meeting.start_time + 30.minutes)
          else
            if !(user.contact_histories.find_by(message: [confirmation_message, upcoming_message]))
              meeting_confirmation_email
            else
              'Too Early'
            end
          end
        else
          'Already Sent'
        end
      else
        'No Email'
      end
    end

    def run_offers_check
      if allowed_offers?
        offer = meeting.offer.deep_symbolize_keys
        offer[:rules].map! {|r| r.gsub(':id', meeting_id.to_s) }
        User.find_by(id: user.id).offers.create(
          assigner: auto_worker,
          **offer
        )
      end
    end

    def meeting_date
      @meeting_date ||= start_time.to_date
    end

    def meeting_confirmation_email
      send_reminder(:registered, confirmation_message)
    end

    def meeting_upcoming_email
      send_reminder(:upcoming, upcoming_message)
    end

    def send_reminder(mail, msg)
      Meeting::ReminderMailer.
      with(
        meeting_id: meeting_id,
        email: user.email,
        user_id: user.id,
        history_id: user.contact_histories.create(
          category: :email,
          message: msg,
          staff_id: auto_worker.category_id
        )&.id
      ).__send__(mail).deliver_later
    end

    def livestorm_registration
      require 'net/http'

      uri = URI('https://app.livestorm.co/api/v1/participants/auth')
      h = BASE_JSON.deep_dup
      h[:webinar_id] = meeting.webinar_uuid
      h[:session_id] = meeting.session_uuid

      if Rails.env.production?
        h[:fields][0][:value] = h[:email] = user.email || 'downundersports@gmail.com'
        h[:fields][1][:value] = user.first
        h[:fields][2][:value] = user.last
        h[:fields][3][:value] = user.dus_id
      end


      req = Net::HTTP::Post.new(uri)
      req.body = h.to_json
      req.content_type = 'application/json;charset=UTF-8'

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      result = http.request(req)

      case result
      when Net::HTTPSuccess, Net::HTTPRedirection
        begin
          user.contact_histories.create(category: :email, message: livestorm_message, staff_id: auto_worker&.category_id)

          result.body || true
        rescue
          true
        end
      else
        begin
          result.value || true
        rescue
          begin
            result.body || true
          rescue
            result || true
          end
        end
      end
    end

    BASE_JSON = {
      webinar_id: "c29abc10-f912-41f5-8a55-8d0066c50172",
      session_id: "03817875-7ee5-4f42-a061-5049477da90b",
      fields: [
        {
          id: "email",
          type: "text",
          label: "",
          order: 0,
          value: "downundersports@gmail.com",
          checked: true,
          disabled: false,
          required: true
        },
        {
          id: "first_name",
          type: "text",
          label: "",
          order: 1,
          value: "Down",
          checked: true,
          disabled: false,
          required: true
        },
        {
          id: "last_name",
          type: "text",
          label: "",
          order: 2,
          value: "Under Sports",
          checked: true,
          disabled: false,
          required: true
        },
        {
          id: "dusid",
          type: "text",
          label: "DUS_ID",
          order: 3,
          value: " AAAAAA",
          custom: true,
          checked: true,
          options: {
            text: "",
            items: [

            ],
            custom_values: false
          },
          disabled: false,
          required: true,
          options_preset: ""
        }
      ],
      email: "downundersports@gmail.com",
      referrer: "https://app.livestorm.co/",
      terms_checked: true,
      terms_text: "I agree to <a href=\"https://livestorm.co/terms\" target=\"_blank\">Livestorm's Terms of Service</a> and the use of personal data as explained in <a href=\"https://livestorm.co/privacy-policy\" target=\"_blank\">Livestorm's Privacy Policy</a>. *",
    }

    set_audit_methods!
  end
end
