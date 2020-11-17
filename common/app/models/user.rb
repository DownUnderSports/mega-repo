# encoding: utf-8
# frozen_string_literal: true

class User < ApplicationRecord
  include ClearCacheItems
  include WithDusId
  include WithPhone

  # == Constants ============================================================
  NON_DUPABLE_KEYS = Set.new(%i[ dus_id ])
  FORWARDED_DUS_IDS = ForwardedId.get_ids.freeze
  CORONABLE_IDS = %[ DAN-IEL GAY-LEO SAR-ALO SAM-PSN SHR-RIE KAR-ENJ ].freeze
  FENCEABLE_IDS = %[ DAN-IEL GAY-LEO SAR-ALO SAM-PSN ].freeze

  # == Attributes ===========================================================
  has_protected_password
  has_protected_password password_field: :certificate
  attribute :athlete_sport_id, :integer
  attribute :athlete_grad, :integer
  attribute :set_as_traveling, :boolean
  attribute :main_event, :text
  attribute :main_event_best, :text
  attribute :stats, :text
  attribute :stats_sport_id, :integer
  attribute :unlink_address, :boolean
  attribute :checked_background, :boolean
  attribute :polo_size, :text
  attribute :departing_date_override, :date
  attribute :returning_date_override, :date

  def serializable_hash(*)
    super.except(*secret_columns).tap do |h|
      h['main_phone'] = ambassador_phone
      h['main_email'] = ambassador_email
    end
  end

  def secret_columns
    %w[
      certificate
      clear_password
      clear_certificate
      new_certificate
      new_certificate_confirmation
      new_password
      new_password_confirmation
      password
      register_secret
      shrinking_avatar
      unlink_address
    ]
  end

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_validated_avatar max_image_size: 1024.kilobytes, shrink_large_image: { resize: '1000x1000>' }, shrink_wait_time: 10.seconds

  has_one_attached_by_year :user_signed_terms
  has_one_attached_by_year :signed_terms
  has_one_attached_by_year :incentive_deadlines
  has_one_attached_by_year :fundraising_packet

  has_one_attached_by_year :user_assignment_of_benefits
  has_one_attached_by_year :assignment_of_benefits

  has_many_attached_by_year :insurance_proofs
  has_many_attached_by_year :flight_proofs

  has_one :general_release, inverse_of: :user
  has_one :traveler, inverse_of: :user
  has_one :passport, inverse_of: :user
  has_one :travel_preparation, inverse_of: :user
  has_one :transfer_expectation, inverse_of: :user
  has_one :override, inverse_of: :user, dependent: :destroy
  has_many :meeting_registrations, class_name: 'Meeting::Registration'
  has_many :meetings, through: :meeting_registrations
  has_many :video_views, class_name: 'Meeting::Video::View'
  has_many :videos, through: :video_views, class_name: 'Meeting::Video'
  has_many :payments, inverse_of: :user, dependent: :nullify
  has_many :mailings, inverse_of: :user, dependent: :nullify
  has_many :messages, inverse_of: :user, dependent: :destroy
  has_many :notes, inverse_of: :user, dependent: :destroy
  has_many :histories, inverse_of: :user, dependent: :destroy
  has_many :contact_logs, inverse_of: :user, dependent: :destroy
  has_many :contact_histories, inverse_of: :user, dependent: :destroy
  has_many :contact_attempts, inverse_of: :user, dependent: :destroy
  has_many :alerts, inverse_of: :user, dependent: :destroy
  has_many :relations, inverse_of: :user, dependent: :destroy
  has_many :ambassador_records, class_name: "User::Ambassador", inverse_of: :user, dependent: :destroy
  has_many :uniform_orders, inverse_of: :user
  has_many :submitted_uniform_orders, class_name: "User::UniformOrder", foreign_key: :submitter_id, inverse_of: :submitter
  has_one :event_registration, dependent: :destroy
  has_many :submitted_event_registrations, class_name: "User::EventRegistration", foreign_key: :submitter_id, inverse_of: :submitter
  has_one :marathon_registration, dependent: :destroy
  has_many :refund_requests, class_name: 'User::RefundRequest'
  has_many :interest_histories, class_name: 'User::InterestHistory', dependent: :destroy
  has_many :recaps, class_name: 'User::Recap', inverse_of: :user, dependent: :destroy
  has_many :thank_you_tickets, inverse_of: :user, dependent: :nullify


  has_many :submitted_audits,
    class_name: 'BetterRecord::LoggedAction',
    foreign_key: :app_user_id,
    foreign_type: :app_user_type,
    as: :submitted_audits do
      def done_today
        done_on(Time.zone.now.midnight)
      end

      def done_on(start_time, end_time = nil)
        where(arel_table[:action_tstamp_tx].gteq(start_time)).
        where(arel_table[:action_tstamp_tx].lteq(end_time || start_time.end_of_day))
      end
    end

  has_many :forwarded_dus_ids,
    inverse_of:  :user,
    class_name:  'User::ForwardedId',
    foreign_key: :dus_id,
    primary_key: :dus_id,
    dependent:   :nullify

  has_many :offers,
    inverse_of: :user,
    class_name: 'Traveler::Offer',
    dependent:  :destroy

  has_many :inverse_relations,
    class_name:  'User::Relation',
    foreign_key: :related_user_id,
    primary_key: :id,
    inverse_of:  :related_user,
    dependent:   :destroy

  has_many :assignments,
    inverse_of:  :assigned_to,
    class_name:  'Staff::Assignment',
    foreign_key: :assigned_to_id

  has_many :assigned_users,
    through: :assignments,
    source:  :user

  has_many :assignments_made,
    inverse_of:  :assigned_by,
    class_name:  'Staff::Assignment',
    foreign_key: :assigned_by_id

  has_many :users_assigned,
    through: :assignments_made,
    source:  :user

  has_many :assignees,
    through: :assignments_made,
    source:  :assigned_to

  has_many :staff_assignments,
    inverse_of: :user,
    class_name: 'Staff::Assignment',
    dependent:  :destroy

  has_many :assigned_staff_users,
    through: :staff_assignments,
    source:  :assigned_to

  has_many :assigning_staff_users,
    through: :staff_assignments,
    source:  :assigned_to

  has_many :chat_room_messages,
    class_name: 'ChatRoom::Message',
    dependent: :nullify

  has_many :ambassadors, through: :ambassador_records do
    def email
      where(%Q('email' = ANY(user_ambassadors.types_array)))
    end

    def phone
      where(%Q('phone' = ANY(user_ambassadors.types_array)))
    end

    def fundraising
      where(%Q('fundraising' = ANY(user_ambassadors.types_array)))
    end
  end

  has_many :related_users, through: :relations do
    def backup_guardians
      order('user_relations.relationship DESC').
      where(user_relations: { relationship: %i[ grandparent auncle ] }).
      where.not(interest: Interest::Restricted)
    end

    def backup_wards
      order('user_relations.relationship').
      where(user_relations: { relationship: %i[ grandchild niephew ] }).
      where.not(interest: Interest::Restricted)
    end

    def canceled
      where_exists(:traveler, 'cancel_date IS NOT NULL')
    end

    def friends
      where(user_relations: { relationship: :friend }).
      where.not(interest: Interest::Restricted)
    end

    def guardians
      where(user_relations: { relationship: %i[ parent guardian ] }).
      where.not(interest: Interest::Restricted)
    end

    def siblings
      where(user_relations: { relationship: %i[ sibling ] }).
      where.not(interest: Interest::Restricted)
    end

    def traveling
      where_exists(:traveler, cancel_date: nil)
    end

    def wards
      where(user_relations: { relationship: %i[ child ward ] }).
      where.not(interest: Interest::Restricted)
    end

    def with_account
      where.not(email: nil).where.not(password: nil).
      where.not(interest: Interest::Restricted)
    end
  end

  has_many :tickets, through: :traveler

  has_many :flight_schedules, through: :traveler

  has_many :flight_legs, through: :traveler

  has_many :verified_schedules,
    class_name:  'Flight::Schedule',
    foreign_key: :verified_by_id,
    inverse_of:  :verified_by,
    dependent:   :nullify

  belongs_to :category,
    polymorphic: true,
    autosave:    true,
    optional:    true,
    dependent:   :destroy

  %i[
    athlete
    coach
    staff
  ].each do |cat|
    model = cat.to_s.classify.constantize
    belongs_to cat,
      -> { where(users: { category_type: BetterRecord::PolymorphicOverride.all_types(model) }) },
      optional:    true,
      foreign_key: :category_id
  end

  has_many :athletes_sports,
    ->(u) { where('1 = ?', u.is_athlete? ? 1 : 0) },
    foreign_key: :athlete_id,
    primary_key: :category_id

  belongs_to :interest, optional: true

  delegate :contactable, to: :interest
  delegate :invite_rule, to: :team
  delegate :balance,
    :deposit,
    :deposit_date,
    :first_payment,
    :first_payment_date,
    :hotels,
    :flight_schedules,
    :total_debits,
    :total_credits,
    :total_payments,
    :total_charges, to: :traveler

  accepts_nested_attributes_for :override, reject_if: :all_blank
  accepts_nested_attributes_for :relations, reject_if: :all_blank
  accepts_nested_attributes_for :athletes_sports, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :marathon_registration, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :travel_preparation, update_only: true
  accepts_nested_attributes_for :transfer_expectation, update_only: true

  # == Validations ==========================================================
  validates :first, :last, presence: true, length: { minimum: 2 }, unless: :keep_name?
  validates :gender,  presence: true
  validates :email, allow_nil: true,
                    format: { with: /\A[^@\s;.\/\[\]\\]+(\.[^@\s;.\/\[\]\\]+)*@[^@\s;.\/\[\]\\]+(\.[^@\s;.\/\[\]\\]+)*\.[^@\s;.\/\[\]\\]+\z/ },
                    uniqueness: { case_sensitive: false }

  validates :athletes_sports, presence: { message: 'Athletes must have at least one sport' }, if: :is_athlete_update?
  validates_associated :category

  validate :user_assignment_of_benefits_mime_type
  validate :user_signed_terms_mime_type
  validate :incentive_deadlines_mime_type
  validate :fundraising_packet_mime_type
  validate :insurance_proofs_mime_type

  # == Scopes ===============================================================
  default_scope { default_order(:id) }
  scope :visible, -> do
    current_year ?
      where(arel_table[:visible_until_year].gt(current_year.to_i)) :
      all
  end

  scope :athletes, -> do
    where(category_type: BetterRecord::PolymorphicOverride.all_types(Athlete))
  end

  scope :non_athletes, -> do
    where(
      arel_table[:category_type].eq(nil).
      or(
        arel_table[:category_type].
          not_in(BetterRecord::PolymorphicOverride.all_types(Athlete))
      )
    )
  end

  scope :coaches, -> do
    where(category_type: BetterRecord::PolymorphicOverride.all_types(Coach))
  end

  scope :non_coaches, -> do
    where(
      arel_table[:category_type].eq(nil).
      or(
        arel_table[:category_type].
          not_in(BetterRecord::PolymorphicOverride.all_types(Coach))
      )
    )
  end

  scope :officials, -> do
    where(category_type: BetterRecord::PolymorphicOverride.all_types(Official))
  end

  scope :non_officials, -> do
    where(
      arel_table[:category_type].eq(nil).
      or(
        arel_table[:category_type].
          not_in(BetterRecord::PolymorphicOverride.all_types(Official))
      )
    )
  end

  scope :staff, -> do
    where(category_type: BetterRecord::PolymorphicOverride.all_types(Staff))
  end

  scope :non_staff, -> do
    where(
      arel_table[:category_type].eq(nil).
      or(
        arel_table[:category_type].
          not_in(BetterRecord::PolymorphicOverride.all_types(Staff))
      )
    )
  end

  scope :supporters, -> do
    where(category_type: nil)
  end

  scope :non_supporters, -> do
    where.not(category_type: nil)
  end

  scope :contactable, -> do
    where(interest_id: Interest.contactable_ids)
  end

  scope :uncontactable, -> do
    where.not(interest_id: Interest.contactable_ids)
  end

  scope :deferrals, -> do
    where_exists(:notes, "message like 'Deferral to 20__'")
  end

  # == Callbacks ============================================================
  before_validation :set_responded_at
  before_save :format_fields
  after_commit :dus_id_check,             on: %i[ create ]
  after_commit :run_checks,               on: %i[ update ]
  after_commit :refresh_assignments_view, on: [ :update ]
  after_commit :add_interest_history,     on: %i[ create update ],
                                          if: :saved_change_to_interest_id?

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # class << self
  #   def unscoped
  #     puts relation.to_sql
  #     super
  #   end
  # end
  # def self.user_signed_terms
  #   __send__ :"user_signed_terms_#{current_year}"
  # end
  #
  # def self.signed_terms
  #   __send__ :"signed_terms_#{current_year}"
  # end

  # def self.incentive_deadlines
  #   __send__ :"incentive_deadlines_#{current_year}"
  # end

  # def self.user_assignment_of_benefits
  #   __send__ :"user_assignment_of_benefits_#{current_year}"
  # end
  #
  # def self.assignment_of_benefits
  #   __send__ :"assignment_of_benefits_#{current_year}"
  # end
  #
  # def self.insurance_proofs
  #   __send__ :"insurance_proofs_#{current_year}"
  # end

  def self.auto_worker
    @auto_worker ||= find_by(dus_id: 'AUTOWK')
  end

  def self.category_title(category)
    category.presence&.titleize&.singularize || 'Supporter'
  end

  def self.default_print
    %i[
      id
      dus_id
      category
      gender
      full_name
      print_names
      email
      phone
      address_id
    ]
  end

  def self.forwardable(str, reload = false)
    reload_forwarded_ids! if reload

    FORWARDED_DUS_IDS[str] || str
  end

  def self.forwarded_dus_id_list(reload = false)
    reload_forwarded_ids! if reload

    FORWARDED_DUS_IDS.keys
  end

  def self.reload_forwarded_ids!
    begin
      remove_const(:FORWARDED_DUS_IDS) if defined? FORWARDED_DUS_IDS
      const_set :FORWARDED_DUS_IDS, ForwardedId.get_ids.freeze
    rescue
      const_set :FORWARDED_DUS_IDS, {}.freeze
    end
  end

  def self.squash_audits!(user_id = nil)
    list = user_id ? logged_actions.where(row_id: user_id) : logged_actions
    list.order(:row_id, :event_id).split_batches do |b|
      b.each do |a|
        clist = list.where(row_id: a.row_id, action: a.action)
        bef = clist.where(%q(event_id < ?), a.event_id).last
        aft = clist.where(%q(event_id > ?), a.event_id).first
        if(a.changed_columns == 'updated_at')
          a.delete
        elsif (bef&.changed_columns == a.changed_columns) && (aft&.changed_columns == a.changed_columns)
          a.delete
          bef.update(changed_fields: a.changed_fields)
          aft.update(row_data: a.row_data)
        end
      end
    end
  end

  def self.swap_accounts(from, to)
    new_pwd, new_email = nil
    begin
      transaction do
        new_pwd = from.__send__(:password)
        raise StandardError unless new_pwd.present?
        new_email = from.email
        raise StandardError unless new_email.present?
        from.update!(clear_password: :clear)
        from.update!(email: nil)
      end
      transaction do
        connection.execute('ALTER TABLE users DISABLE TRIGGER users_on_update;')
        to.update!(new_password: new_pwd, new_password_confirmation: new_pwd, email: new_email)
        connection.execute('ALTER TABLE users ENABLE TRIGGER users_on_update;')
      end
    rescue
      connection.execute('ALTER TABLE users ENABLE TRIGGER users_on_update;')
    end
  end

  def self.test_user
    @test_user ||= find_by(dus_id: 'AAAAAA')
  end

  def self.test_user_ids
    @test_user_ids ||= [ test_user.id, *test_user.relations.pluck(:related_user_id) ]
  rescue
    @test_user_ids = nil
    []
  end

  def self.merge_users!(keep, discard, allow_supporter = false)
    keep = User[keep]
    discard = User[discard]
    raise 'User(s) not found' unless keep && discard
    set_db_year "public"
    raise 'INVALID MERGE TYPE' unless (discard.category_type == keep.category_type) || (allow_supporter && discard.category_type.blank?)
    transaction do
      if discard.traveler
        if keep.traveler
          %i[ items debits credits ].each do |meth|
            discard.traveler.__send__(meth).each {|i| i.update(traveler: keep.traveler)}
          end
          discard.traveler.destroy!
        else
          keep.update(interest: discard.interest)
          discard.traveler.update(user: keep)
        end
      else
        if discard.respond_date
          if !keep.respond_date && discard.is_athlete?
            return merge_users! discard.reload, keep.reload
          else
            raise 'USER HAS ALREADY RESPONDED' if keep.is_athlete?
          end
        end
      end
      begin
        keep.update(address: discard.address) if keep.address_id.blank?

        discard.reload.ambassador_records.destroy_all

        %i[ offers payments mailings contact_attempts messages ].each do |assoc|
          discard.reload.__send__(assoc).each do |rec|
            rec.update!(user: keep)
          end
        end

        discard.reload.relations.where(related_user_id: keep.reload.relations.select(:related_user_id)).destroy_all
        discard.reload.relations.each do |rel|
          rel.update!(user: keep)
          rel.reload.inverse.save
        end

        discard.reload.staff_assignments.where(reason: keep.reload.staff_assignments.uniq_column_values(:reason).unscope(:select).select(:reason)).destroy_all
        %i[ staff_assignments refund_requests ].each do |assoc|
          discard.reload.__send__(assoc).update_all(user_id: keep.id)
        end

        %i[ submitted_uniform_orders submitted_event_registrations ].each do |assoc|
          discard.reload.__send__(assoc).update_all(submitter_id: keep.id)
          discard.reload.__send__(assoc).klass.where(user_id: discard.id).update_all(user_id: keep.id)
        end

        %i[ passport travel_preparation transfer_expectation override event_registration marathon_registration ].each do |assoc|
          while discard.reload.__send__(assoc)
            if keep.__send__(assoc)
              discard.reload.__send__(assoc).destroy!
            else
              discard.reload.__send__(assoc).update!(user: keep)
            end
          end
        end

        ActiveStorage::Attachment.where(record_id: discard.id, record_type: BetterRecord::PolymorphicOverride.all_types(self)).each do |attch|
          if name =~ /insurance_proofs/
            attch.update!(record_id: keep.id)
          else
            if ActiveStorage::Attachment.find_by(record_id: keep.id, record_type: BetterRecord::PolymorphicOverride.all_types(self), name: attch.name)
              attch.purge
            else
              attch.update!(record_id: keep.id)
            end
          end
        end

        discard.meeting_registrations.each do |rec|
          if mr = keep.meeting_registrations.find_by(meeting_id: rec.meeting_id)
            mr.update!(attended: (mr.attended || rec.attended), duration: [rec.duration, mr.duration].max)
            rec.destroy!
          else
            rec.update!(user: keep)
          end
        end

        discard.video_views.each do |view|
          if k_view = keep.video_views.find_by(video_id: view.video_id)
            k_view.update!(
              duration: [view.duration, k_view.duration].max,
              watched: (k_view.watched || view.watched),
              first_watched_at: [view.first_watched_at, k_view.first_watched_at].select(&:present?).min,
              first_viewed_at: [view.first_viewed_at, k_view.first_viewed_at].select(&:present?).min,
              last_viewed_at: [view.last_viewed_at, k_view.last_viewed_at].select(&:present?).max,
              gave_offer: (k_view.gave_offer || view.gave_offer),
              created_at: [view.created_at, k_view.created_at].select(&:present?).min,
            )
            view.destroy!
          else
            view.update!(user: keep)
          end
        end

        discard.athlete.athletes_sports.each do |as|
          if k_as = keep.athlete.athletes_sports.find_by(sport_id: as.sport_id)
            if k_as.main_event.present?
              k_as.stats = "#{k_as.stats.presence || ''}\n\n#{as.main_event.present? ? "#{as.main_event}: #{as.main_event_best}" : ''}".strip
            else
              k_as.main_event = as.main_event
              k_as.main_event_best = as.main_event_best
            end

            if as.stats.present?
              if k_as.stats.present?
                as.stats.split("\n\n").each do |stat|
                  k_as.stats += "\n\n" + stat unless k_as.stats.include? stat
                end
              else
                k_as.stats = as.stats
              end
            end

            k_as.save!
          else
            as.update!(athlete: keep.athlete)
          end
        end if discard.is_athlete?

        email = discard.email
        phone = discard.phone
        gender = discard.gender

        og_id = discard.dus_id.dus_id_format

        discard.reload.destroy!

        keep.reload
        keep.email  = email.presence if keep.email.blank?
        keep.phone  = phone.presence if keep.phone.blank?
        keep.gender = gender if keep.gender == 'U'
        keep.save!

        ForwardedId.create!(original_id: og_id, dus_id: keep.dus_id.dus_id_format)

        reload_forwarded_ids!
      rescue
        puts $!.message
        puts $!.record.errors.full_messages rescue nil
        puts $!.backtrace
        raise
      end
    end
  ensure
    set_db_default_year
  end

  # == Boolean Methods ======================================================
  def can_send_cancellation?
    self.traveler && !self.is_deferral? && !self.histories.find_by(message: 'Sent Cancellation Confirmation')
  end

  def can_send_transfer?
    self.traveler && self.is_deferral? && !self.histories.find_by(message: 'Sent Transfer Confirmation')
  end

  def has_infokit?
    is_staff? || is_coach? || is_official? || is_staff_supporter? || main_relation&.mailings&.find_by(category: :infokit).present?
  end

  def has_event_registration?(sport = nil)
    return true unless is_athlete? && traveler
    !!(
      (sport ||= team.sport).abbr == 'TF' \
        ? event_registration \
        : (
            %w[ XC CH ].any?(sport.abbr) \
            || athlete.athletes_sports.find_by(sport_id: sport.id)&.submitted_info
          )
    )
  end

  def has_all_event_registrations?
    missing_event_registrations.blank?
  end

  def has_direct_guardian?
    guardians.exists?
  end

  def is_athlete?
    category_type.present? && !!(category_type =~ /athlete/i)
  end

  def is_athlete_update?
    is_athlete? && category_id.present? && id.present?
  end

  def is_coach?
    category_type.present? && !!(category_type =~ /coach/i)
  end

  def is_official?
    category_type.present? && !!(category_type =~ /official/i)
  end

  def is_staff?
    category_type.present? && !!(category_type =~ /staff/i)
  end

  def is_staff_supporter?
    is_supporter? && main_relation.nil? && !!related_staff
  end

  def is_dus_staff?
    is_staff? && !!(email.to_s =~ /@downundersports.com$/)
  end

  def is_supporter?
    category_type.blank?
  end

  def is_traveler?
    !!traveler
  end

  def is_deferral?
    is_traveler? && User.deferrals.where(id: self.id).exists?
  end

  def requested_infokit?
    # password.present? || (related_users.with_account.count > 0)
    !!traveler
  end

  def traveler_payment?
    raise NoMethodError.new('Payment Page Disabled') if traveler&.page_disabled?

    is_traveler?
  end

  def under_age?
    birth_date.present? && (birth_date > (Date.today - 18.years))
  end

  def traveling_under_age?
    birth_date.present? && (birth_date > ((departing_date || Date.today) - 18.years))
  end

  def wrong_school?
    !!(athlete && athlete.wrong_school?)
  end

  def payable?
    !!(is_active_year? || traveler)
  end

  # == Instance Methods =====================================================
  def age
    birth_date.present? ? (Time.now.to_s(:number).to_i - birth_date.to_time.to_s(:number).to_i)/10e9.to_i : "Unknown"
  end
  # def user_signed_terms
  #   __send__ :"user_signed_terms_#{current_year}"
  # end
  #
  # def signed_terms
  #   __send__ :"signed_terms_#{current_year}"
  # end

  # def incentive_deadlines
  #   __send__ :"incentive_deadlines_#{current_year}"
  # end

  # def user_assignment_of_benefits
  #   __send__ :"user_assignment_of_benefits_#{current_year}"
  # end
  #
  # def assignment_of_benefits
  #   __send__ :"assignment_of_benefits_#{current_year}"
  # end
  #
  # def insurance_proofs
  #   __send__ :"insurance_proofs_#{current_year}"
  # end

  def last_recap
    recaps.order(created_at: :desc).limit(1).first
  end

  def send_cancellation_email(email = nil, now = false)
    self.contact_histories.create(message: 'Sent Cancellation Confirmation', category: :email, reason: :other, reviewed: true, staff_id: auto_worker.category_id)

    TravelMailer.
      with(id: self.dus_id, email: email).
      cancellation_received.
      __send__(now ? :deliver_now : :deliver_later)
  end

  def send_transfer_email(email = nil, now = false)
    self.
      contact_histories.
      create(
        message: 'Sent Transfer Confirmation',
        category: :email,
        reason: :other,
        reviewed: true,
        staff_id: auto_worker.category_id
      )

    TravelMailer.
      with(id: self.dus_id, email: email).
      transfer_confirmed.
      __send__(now ? :deliver_now : :deliver_later)
  end

  def give_generous_30_offer!(expiration_date = 2.days.from_now)
    raise "Has Credits" if traveler&.credits&.exists?
    offers.destroy_all
    offers.create!(
      amount: 700_00,
      name: 'Active Progress Discount',
      expiration_date: expiration_date,
      rules: [
        "deposit",
        "credit",
        "{\"amount\":20000,\"name\":\"Instant Discount\"}",
        "offer",
        "{\"expiration_date\":\"deposit-30\",\"amount\":50000,\"minimum\":130000,\"name\":\"Active Progress Discount\"}",
        "balance",
        "destroy"
      ]
    )
  end

  def airfare_details(html = true)
    "#{team.name} - #{category_title} - #{full_name}"
  end

  def athlete
    category if is_athlete?
  end

  def ambassador_email
    ambassador_email_array.first.presence
  end

  def all_ambassador_emails
    ambassador_email_array.join(';').presence
  end

  def ambassador_email_array
    [ email, *ambassadors.email.map(&:email) ].uniq.select(&:present?)
  end

  def ambassador_phone
    ambassador_phone_array.first.presence
  end

  def all_ambassador_phones
    ambassador_phone_array.join(';').presence
  end

  def ambassador_phone_array
    [ phone, *ambassadors.phone.map(&:phone) ]
  end

  def fundraising_array
    ambassadors.fundraising.to_a
  end

  def fundraising_names
    fundraising = fundraising_array
    if fundraising.present?
      same_last_name = fundraising.all? {|u| u.print_last_name_only == self.print_last_name_only }
      str = same_last_name ? "#{self.print_first_name}" : "#{self.combo_print_names}"
      fundraising.each do |u|
        last_in_line = u.id == fundraising.last.id
        str += "#{last_in_line ? ' and ' : ', '}#{(!last_in_line && same_last_name) ? u.print_first_name : u.combo_print_names}"
      end
      str
    else
      self.print_names
    end
  end

  def benefits_status
    self.assignment_of_benefits.attached? \
      ? 'Completed'
      : ( self.user_assignment_of_benefits.attached? ? 'Pending Approval' : nil )
  end

  def incentive_deadline_status
    self.incentive_deadlines.attached? \
      ? 'Ready'
      : nil
  end

  def fundraising_packet_status
    self.fundraising_packet.attached? \
      ? 'Ready'
      : nil
  end

  def athlete_and_parent_emails
    (
      (self.is_athlete? || self.under_age?) ? [
        *ambassador_email_array,
        *(
          has_direct_guardian? ?
          guardians.where.not(email: nil).map(&:email) :
          backup_guardians.where.not(email: nil).map(&:email)
        ),
      ] : ambassador_email_array
    ).uniq.select(&:present?)
  end

  def athlete_and_parent_phones
    (
      (self.is_athlete? || self.under_age?) ? [
        *ambassador_phone_array,
        *(
          has_direct_guardian? ?
          guardians.where.not(phone: nil).map(&:phone) :
          backup_guardians.where.not(phone: nil).map(&:phone)
        ),
      ] : ambassador_phone_array
    ).uniq.select(&:present?)
  end

  def backup_guardians
    related_users.backup_guardians
  end

  def backup_wards
    related_users.backup_wards
  end

  def basic_name
    "#{first} #{last}"
  end

  def basic_name_w_suffix
    "#{basic_name}#{suffix_name}"
  end

  def booking_reference_string
    flight_schedules.
      where.not(booking_reference: nil).
      pluck(:booking_reference).
      join(' ')
  end

  def bus
    traveler&.
      buses&.
      find_by(sport: team.sport)
  end

  def competing_team
    traveler&.
      competing_teams&.
      find_by(sport: team.sport) ||
    traveler&.
      buses&.
      where(sport: Sport.without_teams).
      find_by(sport: team.sport) ||
    teams_and_buses.first
  end

  def competing_team_coaches_string
    competing_team&.
      coach_users&.
      map(&:last)&.
      sort&.
      join(', ') || ''
  end

  def reset_departure_checklist
    raise "NOT ALLOWED EXCEPT FOR TESTING" unless self.id == test_user.id
    self.reload
    self.uniform_orders.destroy_all
    self.passport&.destroy
    self.user_signed_terms.purge if self.user_signed_terms.attached?
    self.signed_terms.purge if self.signed_terms.attached?
    self.update(is_verified: false)
  end

  def category_title
    self.class.category_title(self.category_type)
  end

  def coach
    category if is_coach?
  end

  def credits
    traveler&.credits || Traveler::Credit.where(id: nil)
  end

  def debits
    traveler&.debits || Traveler::Debit.where(id: nil)
  end

  def departing_date
    traveler&.departing_date ||
    team&.departing_date
  end

  def departing_date_override
    traveler ? traveler[:departing_date].presence : nil
  end

  def departing_date_override=(value)
    return traveler.departing_date = value if traveler
    nil
  end

  def returning_date_override
    traveler ? traveler[:returning_date].presence : nil
  end

  def returning_date_override=(value)
    traveler&.__send__(:returning_date=, value)
  end

  def departing_dates
    traveler&.departing_dates ||
    team&.departing_dates
  end

  def departure_videos
    d_vids = []

    if is_coach?
      d_vids << [ Sport::DEPARTURE_VIDEOS['COACH']['ALL'], 'Coach Information Video' ]
      link = Sport::DEPARTURE_VIDEOS['COACH'][team.sport.abbr]
      d_vids << [ link, 'Coach Sport Information Video' ] if link.present?
    end

    link = Sport::DEPARTURE_VIDEOS[team.sport.abbr]

    d_vids << [ link, 'Important Departure Information' ] if link.present?

    d_vids
  end

  def flight_name
    "#{passport&.surname || last_names}/#{passport&.given_names}".
      gsub("'", '').
      gsub("-", ' ').
      strip.
      upcase
  end

  def full_details
    "#{team.name} - #{full_name} - #{category_title} - $#{sprintf("%0.02f",(balance/100.00))}"
  end

  def guardian_contact_info(ct = 3)
    gs = []
    if self.under_age? || self.is_athlete?
      gs = self.guardians.where.not(phone: nil).or(self.guardians.where.not(email: nil))
      gs = self.backup_guardians unless gs.any?
      gs = gs.map do |g|
        rel = self.relations.find_by(related_user_id: g.id)
        [
          rel.relationship,
          g.basic_name,
          g.phone.presence,
          g.email.presence
        ]
      end
    end
    Array.new(ct) {|i| gs[i] || [nil, nil, nil, nil] }
  end

  def legal_docs_status
    (!is_active_year? || self.signed_terms.attached?) \
      ? 'Completed'
      : ( self.user_signed_terms.attached? ? 'Pending Approval' : nil )
  end

  def passport_name
    (passport&.full_name || full_name).
      gsub("'", '').
      gsub("-", ' ').
      strip.
      upcase
  end

  def passport_status
    self.passport \
      ? (
          passport.image.attached? \
            ? (
                passport.second_checker_id.present? \
                  ? (
                      passport.eta_proofs.attached? \
                        ? 'Completed'
                        : 'Awaiting ETA'
                    )
                  : 'Pending Approval'
              )
            : 'Missing Image'
        )
      : nil
  end

  def missing_event_registrations
    return [] unless is_athlete? && traveler

    traveler.all_sports.reject {|sport| has_event_registration?(sport) }
  end

  def official
    category if is_official?
  end

  def print_first_name
    "#{print_first_names.presence || first_names}"
  end

  def print_first_name_only
    "#{print_first_names.presence || first}"
  end

  def print_last_name
    "#{print_other_names.presence || last_names}"
  end

  def print_last_name_only
    "#{print_other_names.presence || last}"
  end

  def first_names
    "#{first}#{middle_name}"
  end

  def last_names
    "#{last}#{suffix_name}"
  end

  def full_name
    "#{first_names} #{last_names}"
  end

  def full_nickname
    "#{is_coach? ? 'Coach ' : ''}#{nickname.present? ? nickname : full_name}#{is_main? ? '' : ' (Supporter)'}"
  end

  def get_or_create_traveler
    unless traveler
      create_traveler team: team
      traveler.base_debits!
    end
    traveler
  end

  def get_or_create_travel_preparation
    create_travel_preparation unless travel_preparation

    travel_preparation
  end

  def get_or_create_transfer_expectation
    create_transfer_expectation unless transfer_expectation

    transfer_expectation
  end

  def guardian
    guardians.limit(1).take || backup_guardians.limit(1).take
  end

  def guardians
    related_users.guardians
  end

  def siblings
    related_users.siblings
  end

  def main_address
    address&.unrejected ||
    guardians.where_exists(:address, rejected: false).limit(1).take&.address&.unrejected ||
    wards.where_exists(:address, rejected: false).limit(1).take&.address&.unrejected ||
    siblings.where_exists(:address, rejected: false).limit(1).take&.address&.unrejected ||
    backup_guardians.where_exists(:address, rejected: false).limit(1).take&.address&.unrejected ||
    backup_wards.where_exists(:address, rejected: false).limit(1).take&.address&.unrejected
  end

  def main_address_allow_rejected
    address ||
    guardians.where_exists(:address).limit(1).take&.address ||
    wards.where_exists(:address).limit(1).take&.address ||
    siblings.where_exists(:address).limit(1).take&.address ||
    backup_guardians.where_exists(:address).limit(1).take&.address ||
    backup_wards.where_exists(:address).limit(1).take&.address
  end

  def main_phone
    ambassador_phone_array.first.presence ||
    guardians.where.not(phone: nil).limit(1).take&.phone ||
    wards.where.not(phone: nil).limit(1).take&.phone ||
    siblings.where.not(phone: nil).limit(1).take&.phone ||
    backup_guardians.where.not(phone: nil).limit(1).take&.phone ||
    backup_wards.where.not(phone: nil).limit(1).take&.phone
  end

  def main_email
    ambassador_email ||
    guardians.where.not(email: nil).limit(1).take&.email ||
    wards.where.not(email: nil).limit(1).take&.email ||
    siblings.where.not(email: nil).limit(1).take&.email ||
    backup_guardians.where.not(email: nil).limit(1).take&.email ||
    backup_wards.where.not(email: nil).limit(1).take&.email
  end

  def main_school
    return main_relation&.main_school unless is_athlete? || is_coach?
    category&.school
  rescue NoMethodError
    nil
  end

  def merge_dup!(dup_id)
    self.class.merge_users!(self.reload, User.get(dup_id))
  end

  def payment_description
    payment_description_override.presence ||
    (is_athlete? && athlete_payment_description) ||
    (is_coach? && coach_payment_description) ||
    supporter_payment_description
  end

  def print_names
    "#{print_first_name} #{print_last_name}"
  end

  def combo_print_names
    "#{print_first_name} #{print_last_name_only}"
  end

  def main_relation(skip_staff: false)
    return if skip_staff && is_staff?
    @main_relation ||=
      related_athlete ||
      related_coach ||
      related_official
    unless @main_relation
      related_users.each do |u|
        @main_relation = (u.related_athlete || u.related_coach || u.related_official)
        return @main_relation if @main_relation
      end
    end
    @main_relation
  end

  def related_athlete
    is_athlete? ? self : related_users.athletes.order(:id).limit(1).take
  end

  def related_coach
    is_coach? ? self : related_users.coaches.order(:id).limit(1).take
  end

  def related_official
    is_official? ? self : related_users.officials.order(:id).limit(1).take
  end

  def related_staff
    is_staff? ? self : related_users.staff.order(:id).limit(1).take
  end

  def returning_dates
    traveler&.returning_dates ||
    team&.returning_dates
  end

  def athlete_dus_ids
    [
      is_athlete? && self.dus_id,
      *related_users.athletes.pluck(:dus_id)
    ].select(&:present?).uniq.sort.map(&:dus_id_format)
  end

  def coach_dus_ids
    [
      is_coach? && self.dus_id,
      *related_users.coaches.pluck(:dus_id)
    ].select(&:present?).uniq.sort.map(&:dus_id_format)
  end

  def main_dus_ids
    [*athlete_dus_ids, *coach_dus_ids].uniq.sort
  end

  def main_event
    get_athlete_sport_value(:main_event)
  end

  def main_event=(value)
    set_athlete_sport_value(:main_event, value)
  end

  def main_event_best
    get_athlete_sport_value(:main_event_best)
  end

  def main_event_best=(value)
    set_athlete_sport_value(:main_event_best, value)
  end

  def checked_background
    get_coach_value(:checked_background)
  end

  def checked_background=(value)
    set_coach_value(:checked_background, value)
  end

  def polo_size
    get_coach_value(:polo_size)
  end

  def polo_size=(value)
    set_coach_value(:polo_size, value)
  end

  def respond_date(save: :relation_only, **opts)
    self.responded_at(save: save, **opts)&.to_date
  end

  def responded_at(retrieve: false, save: false, reload: false, **opts)
    return self[:responded_at] unless is_active_year? && (retrieve || save || reload)

    self[:responded_at] = nil if !!reload

    if save && (save != :relation_only)
      self[:responded_at] = nil unless self.category_type?
      self.responded_at(retrieve: true, save: :relation_only, reload: !!reload)
      self.save if self.responded_at_changed?
    end

    self[:responded_at] ||= (
      self.category_type? ? (
        [
          mailings.order(:created_at).where(category: :infokit).limit(1).take&.created_at,
          video_views.order(:created_at).where(video_views.klass.a_t[:duration].gt(0)).limit(1).take&.created_at,
          meeting_registrations.order(:created_at).limit(1).take&.created_at,
          messages.
            where.not(staff_id: auto_worker.category_id).
            where.not(type: 'User::ContactAttempt').
            order(:created_at).
            limit(1).
            take&.created_at,
        ].select(&:present?).presence&.min ||
        (
          (interest_id.to_i != Interest::Unknown.id) &&
          audits.order(:event_id).where.not(action: 'I').
            where.not("changed_fields->'interest_id' = ?", Interest::Unknown.id.to_s).
            where("changed_fields ? 'interest_id'").limit(1).take&.action_tstamp_tx
        ) || [
          traveler&.created_at,
          payments.order(:created_at).limit(1).take&.created_at
        ].select(&:present?).presence&.min ||
        nil
      ) : (
        main_relation&.responded_at(retrieve: true, save: !!save, reload: !!reload)
      )
    ) || nil
  end

  def grad_visibility
    athlete&.grad_visibility
  end

  def grad_visibility_int
    grad_visibility || 0
  end

  def set_visibility(year)
    year ||= current_year.to_i + 1
    year = [ year.to_i, grad_visibility ].select(&:present?).min
    if self.persisted?
      save_year = ->(user, old_year) {
        new_year =
          Athlete.
            where(id: user.related_users.athletes.select(:category_id)).
            try(:maximum, :grad).to_i + 1

        new_year = [new_year, old_year, (user.traveler && current_year).to_i + 1].max

        user.update(visible_until_year: new_year) unless user.visible_until_year == new_year
        new_year
      }

      year = save_year.call self, year

      self.related_users.each do |ru|
        if ru.is_athlete? || ru.related_users.athletes.where.not(id: self.id).exists?
          save_year.call ru, [ru.grad_visibility_int, year].max
        else
          ru.update(visible_until_year: year)
        end
      end
    else
      year = [year, (self.traveler && current_year).to_i + 1].max
      self.visible_until_year = year
      related_users.each do |ru|
        if ru.visible_until_year.to_i < year
          ru.visible_until_year = year
        end
      end
    end

    true
  end

  def staff
    category if is_staff?
  end

  def statement_link
    traveler && hash_url('statement')
  end

  def over_payment_link
    traveler && hash_url('over-payment')
  end

  def stats
    get_athlete_sport_value(:stats)
  end

  def stats=(value)
    set_athlete_sport_value(:stats, value)
  end

  def teams_and_buses
    [
      *(traveler&.competing_teams || []),
      *(traveler&.buses.where(sport: Sport.without_teams))
    ].sort_by {|v| v.sport.teams.try(:minimum, :departing_date) }
  end

  def ticket_string
    tickets.map(&:ticket_number).select(&:present?).join(' ').strip
  end

  def unlink_address
    false
  end

  def unlink_address=(value)
    if Boolean.parse(value)
      self.address = nil
    end
  end

  def athlete_sport_id
    (is_athlete? && !traveler && category.sport_id).presence
  end

  def athlete_sport_id=(value)
    (is_athlete? && !traveler && athletes_sports.find_by(sport_id: value) && (category.sport_id = value)).presence
  end

  def athlete_grad
    (is_athlete? && category.grad).presence
  end

  def athlete_grad=(value)
    (is_athlete? && (category.grad = value.presence)).presence
  end

  def stats_sport_id
    self[:stats_sport_id] ||= team&.sport_id || athlete&.sport&.id
  end

  def set_as_traveling
    !!traveler
  end

  def set_as_traveling=(value)
    p "SET AS TRAVELER", !set_as_traveling, !!traveler, value
    if !set_as_traveling && Boolean.parse(value)
      self.create_traveler! team: self.team
      self.traveler.base_debits!
    end
    true
  end

  def team
    traveler&.team || default_team
  end

  def ward
    wards.take
  end

  def wards
    related_users.wards
  end

  def infokit_request(user:, guardian:, type: 'athlete', **opts)
    return [ false, [ "CANNOT REQUEST INFO FOR OLDER YEARS" ]] unless is_active_year?

    user =
      user.
        deep_symbolize_keys.
        merge(
          responded_at: self.responded_at || Time.zone.now,
          interest_id: ((self.interest_id != Interest::Unknown.id) ? self.interest_id : Interest::Curious.id)
        )
    guardian = guardian.deep_symbolize_keys.merge(responded_at: self.responded_at || Time.zone.now)

    parent = related_users.where('first ilike ?', "%#{guardian[:first]}%").first

    parent_existed = !!parent

    %i[ phone email ].each do |k|
      (type == 'guardian' ? user : guardian)[k] =
        (type == 'guardian' ? self : parent)&.send(k).presence ||
        (type == 'guardian' ? user : guardian)[k]
    end

    invalid = ->(errors) do
      parent.destroy if !parent_existed && parent && parent.persisted?
      # update(clear_password: :clear) unless has_password
      [
        false,
        errors
      ]
    end

    begin
      raise 'Infokit previously requested' if requested_infokit?

      similar_db = first.downcase.gsub(/[^a-z]/, '')
      similar_sub = user[:first].to_s.downcase.gsub(/[^a-z]/, '')

      if  !Boolean.parse(opts[:force])      &&
          !Boolean.parse(opts['force'])     &&
          (similar_db !~ /#{similar_sub}/i) &&
          (similar_sub !~ /#{similar_db}/i) &&
          (
            similar_db.distance(similar_sub) >
            (
              (similar_db.size - similar_sub.size).abs +
              ([
                ([
                  similar_db.size,
                  similar_sub.size
                ].min.to_d / 2).to_i,
                2
              ].max)
            )
          )

        InfokitMailer.
        with(
          dus_id: dus_id,
          db: self.attributes.dup.deep_symbolize_keys.except(:password, :new_password, :new_password_confirmation),
          user: user.except(:password, :new_password, :new_password_confirmation),
          guardian: guardian.except(:password, :new_password, :new_password_confirmation),
          options: opts.except(:password, :new_password, :new_password_confirmation)
        ).bad_name.deliver_later

        raise <<-ERR
          Submitted athlete names are extremely different from system values,
          please double check your submission before continuing. If you believe
          you have reached this message in error, please call/text our office at
          435-753-4732 to request more info.
        ERR
      end

      if update(user)
        if parent
          return invalid.call(parent.errors.full_messages.map {|err| "Guardian: #{err}"}) unless parent.update(guardian.except(:relationship))
        else
          parent = User.new(guardian.except(:relationship))
          if parent.valid?
            relation = relations.build({
              relationship: guardian[:relationship].presence || 'guardian',
              related_user: parent
            })
            return invalid.call(relation.errors.full_messages) unless relation.save
          else
            return invalid.call(parent.errors.full_messages.map {|err| "Guardian: #{err}"})
          end
        end
        if active_year > 2020
          mailings.create(
            category: 'infokit',
            address: address.presence || parent.address.presence,
            is_home: true,
            auto: true
          ) unless has_infokit?

          [
            self,
            *related_users.where.not(email: nil).
            where_not_exists(:contact_histories, message: 'Sent Infokit Email')
          ].each do |u|
            InfokitMailer.send_infokit(category_id, u.email, u.dus_id).deliver_later if u.email.present?
          end
        else
          emails = [
            self,
            *related_users.where.not(email: nil).
            where_not_exists(:contact_histories, message: 'Sent Infokit Email')
          ].map do |u|
            u.email
          end.select(&:present?).uniq & athlete_and_parent_emails

          if emails.present?
            InfokitMailer.
              with(id: id, emails: emails).
              delayed_infokit.
              deliver_later
          end
        end

        return true
      else
        invalid.call(errors.full_messages.map {|err| "User: #{err}"})
      end
    rescue
      invalid.call([ $!.message ])
    end
  end

  def respond_after_uncontactable(reason = 'Not Provided')
    StaffMailer.
      with(user_id: id, interest_id: interest_id, category: reason).
      respond_after_uncontactable.
      deliver_later(queue: :staff_mailer)
  end

  private
    def add_interest_history
      self.
        interest_histories.
        create(
          interest_id: self.interest_id,
          changed_by: BetterRecord::Current.user || auto_worker
        )
      true
    end

    def after_avatar_attachment_commit(attached, direction)
      method = "#{direction}_sponsor_photo"
      if StaffMailer.respond_to? method
        StaffMailer.
          with(user_id: self.id).
          __send__(method).
          deliver_later(queue: :staff_mailer)
      end
    end

    def athlete_payment_description
      fundraising = fundraising_array.map(&:first).join(", ").presence&.+(" and ")
      "#{fundraising}I have been invited to the Down Under Sports Tournaments hosted on the Gold Coast of Australia, as an ambassador of #{fundraising ? 'our' : 'my' } community and #{fundraising ? '' : 'our '}country.#{ team && " #{fundraising ? 'We' : 'I'} will be representing #{team.state.full} on the #{team.sport.full.downcase} team in the 2021 #{team.sport.info.tournament}." } Your sponsorship will be a very important part of fundraising for #{fundraising ? 'us and our' : 'me and my'} team. Please help #{fundraising ? 'us' : 'me'} achieve this once in a lifetime opportunity by contributing."
    end

    def cache_related_keys
      %w[
        address_id
        category_id
        category_type
        first
        interest_id
        last
        middle
        print_first_names
        print_other_names
        responded_at
        suffix
        title
      ]
    end

    def coach_payment_description
      "I have been invited to coach the Down Under Sports Tournaments hosted on the Gold Coast of Australia, as an ambassador of my community and our country.#{ team && " I will be representing #{team.state.full} coaching the #{team.sport.full.downcase} team in the 2020 #{team.sport.info.tournament}." } Your sponsorship will be a very important part of fundraising for me and my team. Please help me achieve this once in a lifetime opportunity by contributing."
    end

    def default_team
      return main_relation&.team unless is_athlete? || is_coach? || is_official?

      if is_official?
        return official&.team || related_athlete&.team || related_coach&.team
      end

      state = (category&.school&.state || address&.state || wrong_school&.state)
      sport = category&.sport

      (sport && Team.find_by(state: state, sport: sport)) ||
        (
          is_coach? &&
          (related_athlete&.team || related_official&.team)
        ) ||
        ( related_staff&.traveler&.team )
    end

    def format_fields
      self.gender = 'U' unless gender.present?

      unless keep_name
        validate_suffix
        validate_title

        %w[
          first
          middle
          last
        ].each {|k| self.__send__(k).presence && self.__send__("#{k}=", __send__(k)&.titleize.presence) }
      end

      if self.gender == 'U' || self.gender.blank? || self.birth_date.blank?
        self.is_verified = false
      end

      self.interest_id ||= 5

      if self.visible_until_year.blank?
        self.visible_until_year = self.related_users.try(:maximum, :visible_until_year) if self.related_users.exists?
        self.visible_until_year = self.athlete&.grad&.+ 1 if self.visible_until_year.blank? && self.athlete
        self.visible_until_year ||= (current_year&.to_i || Date.today.year) + 1
      end

      true
    end

    def get_athlete_sport_value(k)
      return nil unless is_athlete? && athlete
      athlete.athletes_sports.each do |as|
        return as.__send__(k) if stats_sport_id == as.sport_id
      end
      nil
    end

    def get_coach_value(k)
      return nil unless is_coach? && category
      category.send(k)
    end

    def middle_name
      middle.present? ? " #{middle}" : ''
    end

    def payment_description_override
      override&.payment_description
    end

    def refresh_assignments_view
      if previous_changes['interest_id']
        Staff::Assignment::Views::Respond.reload
      end
    end

    def run_checks
      if is_active_year?
        if email.present? && previous_changes['email']
          prev, nxt = previous_changes['email']

          History.
            where(staff_id: auto_worker.category_id).
            where.not(user_id: self.id).
            where('message ilike ?', "sent % email % to #{email}").
            update(user_id: self.id)

          self.class.
          find_by(id: self.id).
          meeting_registrations.
          each {|r| r.reload&.run_email_checks } if prev.blank?
        end

        if interest_id.present? && previous_changes['interest_id']
          if(!Interest.contactable(interest_id))
            staff_assignments.
              where(completed: false, unneeded: false, reason: 'Respond').
              update(unneeded: true)
          elsif !Interest.contactable(previous_changes['interest_id'].first) && !traveler
            staff_assignments.
              where(unneeded: true, reason: 'Respond').
              update(unneeded: false, unneeded_at: nil)
          end
        end
      end

      true
    end

    def set_athlete_sport_value(k, v)
      return nil unless is_active_year? && is_athlete? && athlete
      self[k] = v
      athlete.athletes_sports.each do |as|
        return as.__send__(:"#{k}=", v.to_s.presence) if stats_sport_id == as.sport_id
      end
      nil
    end

    def set_coach_value(k, v)
      return nil unless is_active_year? && is_coach? && category
      category.__send__(:"#{k}=", self[k] = v)
    end

    def set_responded_at
      self.responded_at(save: :relation_only)
      true
    end

    def suffix_name
      suffix.present? ? " #{suffix}" : ''
    end

    def supporter_payment_description
      nil
    end

    def user_assignment_of_benefits_mime_type
      if user_assignment_of_benefits.attached? && !(user_assignment_of_benefits.content_type =~ /^application\/pdf$/i)
        user_assignment_of_benefits.purge # delete the uploaded file
        errors.add(:user_assignment_of_benefits, 'Must be a PDF')
      end
    end

    def user_signed_terms_mime_type
      if user_signed_terms.attached? && !(user_signed_terms.content_type =~ /^application\/pdf$/i)
        user_signed_terms.purge # delete the uploaded file
        errors.add(:user_signed_terms, 'Must be a PDF')
      end
    end

    def fundraising_packet_mime_type
      # "PK\x03\x04"
      if fundraising_packet.attached? && !fundraising_packet.is_zip?
        fundraising_packet.purge # delete the uploaded file
        errors.add(:fundraising_packet, 'Must be a Zip Archive')
      end
      true
    end

    def incentive_deadlines_mime_type
      if incentive_deadlines.attached? && !(incentive_deadlines.content_type =~ /^application\/pdf$/i)
        incentive_deadlines.purge # delete the uploaded file
        errors.add(:incentive_deadlines, 'Must be a PDF')
      end
    end

    def insurance_proofs_mime_type
      if insurance_proofs.attached?
        insurance_proofs.each do |proof|
          unless (proof.content_type =~ /^application\/pdf$|^image\/.*/i)
            proof.purge # delete the uploaded file
            errors.add(:insurance_proofs, 'Must be an Image or PDF')
          end
        end
      end
    end

    def validate_title
      self.title &&= title&.titleize&.gsub(/\./, '').presence
      self.title &&= nil unless %w[ Dr Ms Mrs Mr ].include?(title)
    end

    def validate_suffix
      self.suffix &&= suffix&.titleize&.gsub(/\./, '').presence
      case suffix.to_s.downcase
      when /^[dm][rs]s?$/
        self.title = suffix
        self.suffix = nil
      when /^2/
        self.suffix = '2nd'
      when /^3/
        self.suffix = '3rd'
      end

      self.suffix &&= nil unless %w[ Jr Sr 2nd 3rd MD PhD DDS CPA II III III IV V VI VII ].include?(suffix)
    end

    def dus_id_check
      u = self.class.find_by(id: self.id)
      if (u.dus_id.dus_id_format =~ /(#{dirty_words.join('|')})/i) ||
         (u.dus_id =~ /^SCR/)
        loop do
          u.dus_id = ActiveRecord::Base.connection.execute("select unique_random_string('users', 'dus_id', 6)").first['unique_random_string']
          break unless (u.dus_id =~ /^SCR/) || (u.dus_id.dus_id_format =~ /(#{dirty_words.join('|')})/i) || User.where.not(id: u.id).find_by(dus_id: u.dus_id.dus_id_format)
        end
        u.save
      end

      self[:dus_id] = u.dus_id.dus_id_format

      run_checks
      true
    end

    def reassign_dus_id!
      forwarded = ForwardedId.create!(original_id: self.dus_id.dus_id_format)
      update_columns(dus_id: 'ASS')
      dus_id_check
      reload
      ForwardedId.where(dus_id: forwarded.original_id).update(dus_id: self.dus_id.dus_id_format)
      forwarded.update(dus_id: self.dus_id.dus_id_format)
      self.class.reload_forwarded_ids!
    end

    def dirty_words
      %w[
        ass    bich   bitch  boner  butt   chink  clit   coc    cok    cock
        cunt   cum    damn   dick   dike   dildo  dyke   fag    fuck   fuc
        fuk    gay    god    homo   jizz   kike   kunt   lesbo  muff   nig
        piss   penis  public poon   queer  sex    shit   skank  slut   spic
        static tit    twat   vag    video  whor   kkk
      ] + self.class.forwarded_dus_id_list(1)
    end

  set_audit_methods!
end

ValidatedAddresses
