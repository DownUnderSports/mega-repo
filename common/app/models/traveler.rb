# encoding: utf-8
# frozen_string_literal: true

class Traveler < ApplicationRecord
  include ClearCacheItems

  # == Constants ============================================================
  NON_DUPABLE_KEYS = Set.new(%i[ user_id ])

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.travelers"
  attribute :departing_dates, :text
  attribute :returning_dates, :text

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :user, inverse_of: :traveler, touch: true
  belongs_to :team

  belongs_to :departing_from_airport,
    class_name: 'Flight::Airport',
    primary_key: :code,
    foreign_key: :departing_from,
    optional: true

  belongs_to :returning_to_airport,
    class_name: 'Flight::Airport',
    primary_key: :code,
    foreign_key: :returning_to,
    optional: true

  has_many :items, class_name: 'Payment::TravelerItem', inverse_of: :traveler do
    def failed
      joins(:payment).where(payments: {successful: false})
    end

    def successful
      joins(:payment).where(payments: {successful: true})
    end
  end

  has_many :credits, inverse_of: :traveler, dependent: :destroy

  has_many :debits, inverse_of: :traveler, dependent: :destroy
  has_many :base_debits, through: :debits, source: :base_debit

  has_many :offers, through: :user

  has_many :rooms, class_name: 'Traveler::Room', inverse_of: :traveler do
    def unassigned
      where(number: nil)
    end
  end

  has_and_belongs_to_many :competing_teams,
    inverse_of: :travelers,
    after_add: :touch_updated_at,
    after_remove: :touch_updated_at

  has_and_belongs_to_many :buses,
    inverse_of: :travelers,
    after_add: :touch_updated_at,
    after_remove: :touch_updated_at

  has_many :tickets, class_name: 'Flight::Ticket', inverse_of: :traveler

  has_many :flight_schedules,
    through:    :tickets,
    source:     :schedule,
    class_name: 'Flight::Schedule',
    inverse_of: :travelers

  has_many :flight_legs, -> { order(:departing_at, :arriving_at) },
    through:    :flight_schedules,
    source:     :legs,
    class_name: 'Flight::Leg',
    inverse_of: :travelers do
      def with_airports
        joins(
          <<-SQL.gsub(/\s*\n?\s+/m, ' ')
            INNER JOIN
              "flight_airports" "departing_airports"
            ON
              "departing_airports"."id" = "flight_legs"."departing_airport_id"
            INNER JOIN
              "flight_airports" "arriving_airports"
            ON
              "arriving_airports"."id" = "flight_legs"."arriving_airport_id"
          SQL
        )
      end
    end

  has_many :arriving_airports,
    through:    :flight_legs,
    source:     :arriving_airport,
    class_name: 'Flight::Airport'
    # ,
    # inverse_of: :arriving_travelers

  has_many :departing_airports,
    through:    :flight_legs,
    source:     :departing_airport,
    class_name: 'Flight::Airport'
    # ,
    # inverse_of: :departing_travelers

  has_many :requests,
    class_name: 'Traveler::Request',
    inverse_of: :traveler

  delegate_blank :departing_date, :returning_date, to: :team
  delegate_blank :dus_id, :first, :last, :print_names, to: :user

  # == Validations ==========================================================
  validates_uniqueness_of :user_id

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  scope :deferrals, -> do
    where(user_id: User.deferrals.select(:id))
  end

  # == Callbacks ============================================================
  before_create :check_active_year
  before_destroy :check_active_year
  after_commit :set_assignments, on: [ :create ]
  after_commit :update_assignments, on: [ :update ]
  after_commit :remove_assignments, on: [ :destroy ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.active
    if block_given?
      Traveler.
        where(cancel_date: nil).
        where.not(user_id: test_user_environment_ids).
        split_batches_values do |t|
          yield t
        end
    else
      Traveler.
        where(cancel_date: nil).
        where.not(user_id: test_user_environment_ids)
    end
  end

  def self.additional_sport_base_debit
    BaseDebit::AdditionalSport
  end

  def self.national_coaches
    if block_given?
      active.where_exists(:debits, name: 'National Coach Tournament Package').split_batches do |b|
        b.each {|t| yield t }
      end
    else
      active.where_exists(:debits, name: 'National Coach Tournament Package')
    end
  end

  def self.flight_packages
    BaseDebit.tournament_packages.where.not(id: BaseDebit.no_international&.id)
  end

  def self.with_flights
    q = Traveler.active.where_exists(:debits, base_debit_id: flight_packages.select(:id))

    if block_given?
      q.split_batches do |b|
        b.each {|t| yield t }
      end
    else
      q
    end
  end

  def self.without_flights
    q = Traveler.active.where_not_exists(:debits, base_debit_id: flight_packages.select(:id))

    if block_given?
      q.split_batches do |b|
        b.each {|t| yield t }
      end
    else
      q
    end
  end

  def self.set_balances
    execute_model_sql_file("set_balances")
  end

  # == Boolean Methods ======================================================
  def active?
    !canceled?
  end

  def canceled?
    cancel_date.present?
  end

  def ground_only?(research = false)
    @ground_only = nil if research

    @ground_only ||= !!self.class.without_flights.find(id)
  end

  def hotels
    Traveler::Hotel.where(id: buses.select(:hotel_id))
  end

  def national_coach?
    active? && (debits.where(name: 'National Coach Tournament Package').count > 0)
  end

  def no_international_flights?
    base_debits.where(id: self.class.flight_packages.select(:id)).size == 0
  end

  def page_disabled?
    canceled? && !!(cancel_reason.to_s =~ /DISABLED$/)
  end

  def competing_in?(sport)
    sport = Sport[sport]
    return false unless sport
    return true if all_sports.any? {|sp| sp.id == sport.id }
  end

  def has_max_offers?
    !!(
      ((offers.sum(:amount) + credits.sum(:amount)).cents > 200_00.cents) ||
      (debits.joins(:base_debit).where.not("(traveler_base_debits.name ilike '%domestic%') OR (traveler_base_debits.name ilike '%additional airfare%')").find_by(amount: 0)) ||
      offers.find_by(name: offer_names) ||
      credits.find_by(name: offer_names)
    )
  end

  def got_founders_day?
    !!credits.find_by(name: 'Founders Day Discount')
  end

  def has_insurance?
    user.insurance_proofs.attached? ||
    !!debits.find_by(base_debit: BaseDebit::Insurance)
  end

  def is_deferral?
    self.class.deferrals.where(id: self.id).exists?
  end

  # == Instance Methods =====================================================
  def add_deposit_only_offer(assigner = auto_worker)
    offers.create!(
      assigner: assigner,
      name: 'Active Progress Discount',
      amount: 500_00,
      minimum: 500_00,
      rules: %w[ payment ]
    ) unless offers.count > 0
  end

  def additional_sport_base_debit
    self.class.additional_sport_base_debit
  end

  def additional_sports
    return @additional_sports if @additional_sports.present?
    @additional_sports = []

    if self.additional_sport_base_debit
      self.debits.where(base_debit_id: additional_sport_base_debit.id).each do |dbt|
        sport = Sport.find_by(full_gender: dbt.description.split("\n").first)
        @additional_sports << sport if sport
      end
    end

    @additional_sports
  end

  def all_sports
    return @all_sports if @all_sports && @additional_sports.present?

    @all_sports = [
      team.sport,
      *additional_sports
    ]
  end

  def arriving_flight
    find_intl_flight 'arriving'
  end

  def base_debits!
    user.update(interest: Interest::Traveling) unless canceled?

    BaseDebit.defaults.each do |bd|
      debits << Debit.new(base_debit: bd, amount: bd.amount, assigner: auto_worker) unless debits.find_by(base_debit: bd)
    end

    base_offer! unless user.is_coach?
  end

  def base_offer!
    unless has_max_offers?
      if (('2020-02-29'.to_date)..('2020-03-17'.to_date)).include? first_payment_date
        offers.create!(
          assigner: auto_worker,
          rules: [
            'deposit',
            'offer',
            {expiration_date: 'deposit-30'}.to_json,
            'percentage'
          ],
          amount: 77_70,
          name: 'Active Progress Discount',
          minimum: 0,
          maximum: 777_00
        )
      else
        offers.create!(
          assigner: auto_worker,
          rules: [
            'deposit',
            'offer',
            {expiration_date: 'deposit-7'}.to_json,
            'balance',
            'alternate',
            'offer',
            {expiration_date: 'deposit-30', amount: 300_00}.to_json,
            'balance'
          ],
          amount: 500_00,
          name: 'Active Progress Discount',
          minimum: 1300_00
        )
      end
    end
  end

  def balance(research = false)
    if destroyed? || (!Boolean.parse(research) && Boolean.parse(self[:balance]))
      return self[:balance]
    end

    self.balance = total_charges - total_payments
  end

  def buses_string
    self.buses.map(&:to_str).join(';').presence
  end

  def competing_teams_string
    self.competing_teams.map(&:to_str).join(';').presence
  end

  def dbag
    min = 2500_00.cents

    return nil unless total_payments >= min

    sum = 0.cents

    items.successful.order(:created_at).each do |i|
      return i if (sum += i.amount) >= min
    end

    nil
  end

  def dbag_date
    @dbag_date ||= dbag&.created_at&.to_date
  end

  def departing_flight
    find_intl_flight 'departing'
  end

  def departing_dates
    self[:departing_date]&.to_s(:long) || self.team.departing_dates
  end

  def deposit_amount
    (user.traveler.got_founders_day? ? 320_00 : 300_00).cents
  end

  def deposit_dollars
    deposit_amount.dollar_str.sub(/\.00/, '')
  end

  def deposit
    sum = 0.cents
    min = deposit_amount
    items.successful.order(:created_at).each do |i|
      return i if (sum += i.amount) >= min
    end
    nil
  end

  def deposit_date
    @deposit_date ||= deposit&.created_at&.to_date
  end

  def find_intl_flight(depart_or_arrive = 'arrive')
    k = depart_or_arrive.to_s =~ /arr/ ? :arriving_airports : :departing_airports

    flight_legs.with_airports.find_by(k => { code: 'BNE' }) \
    || flight_legs.with_airports.find_by(k => { code: 'OOL' })
  end

  def first_payment
    @first_payment ||= items.successful.order(:created_at).limit(1).take
  end

  def first_payment_date
    first_payment&.created_at&.to_date
  end

  def insurance_charge
    insurance_debit&.amount.to_i.cents
  end

  def insurance_debit
    debits.find_by(base_debit: BaseDebit::Insurance)
  end

  def insurance_price
    charged = [
      [ total_insurance_charges.to_i, 10000_00 ].min,
      0
    ].max

    Debit::INSURANCE_PRICES.
      select {|price| price === charged }.
      values.
      first.
      to_i.
      cents
  end

  def international_flights
    [
      arriving_flight,
      departing_flight
    ]
  end

  def joined_at
    (first_payment || self).created_at
  end

  def join_date
    joined_at.to_date
  end

  def offers
    user.offers
  end

  def reload
    @deposit_date = @first_payment = nil
    super
  end

  def returning_dates
    self[:returning_date]&.to_s(:long) || self.team.returning_dates
  end

  def set_details(should_set_balance: true, should_set_airports: true, should_save_details: false)
    balance(true) if should_set_balance

    if should_set_airports
      if ground_only?(true)
        self.own_flights = true
      else
        self.own_flights = false
        self.departing_from,
        self.returning_to =
          flight_points
      end
    end

    save! if should_save_details
  end

  def set_insurance_price
    if dbt = insurance_debit
      Debit.insurance(dbt.assigner, self)
    end
  end

  def status
    active? ? 'Active' : (is_deferral? ? 'Deferred' : 'Canceled')
  end

  def total_debits
    StoreAsInt.money debits.sum(:amount)
  end

  def total_credits
    StoreAsInt.money credits.sum(:amount)
  end

  def total_main_credits
    total_credits - total_transfer_credits
  end

  def total_transfer_credits
    StoreAsInt.money credits.where("name like '20__ Transfer'").sum(:amount)
  end

  def total_charges
    total_debits - total_credits
  end

  def total_charges_full
    total_debits - total_main_credits
  end

  def total_insurance_charges
    total_charges_full - insurance_charge
  end

  def total_charges_before_travel
    departing_date ?
      StoreAsInt.money(
        debits.where("created_at < ?", departing_date.midnight).sum(:amount) -
        credits.where("created_at < ?", departing_date.midnight).sum(:amount)
      ) :
      total_charges
  end

  def total_payments
    StoreAsInt.money items.sum(:amount)
  end

  alias :cancelled? :canceled?
  alias :payments :items

  private
    def cache_match_str
      user.__send__ :cache_match_str
    end

    def cache_related_keys
      %w[
        cancel_date
        departing_date
        departing_from
        returning_date
        returning_from
        team_id
      ]
    end

    def flight_points
      return ['LAX', 'LAX'] if debits.find_by(base_debit: Traveler::BaseDebit::OwnDomestic)
      debits.find_by(base_debit: Traveler::BaseDebit::Domestic)&.name.to_s.sub(/^.*?:\s*/, '').split('-')
    end

    def offer_names
      [
        'Early Progress Discount',
        'Active Progress Discount',
        'Alumni Discount',
        'GBR Offer',
        'Great Barrier Reef Discount',
        'Black Friday Discount',
        'New Year Discount',
        'Founders Day Discount',
        'Lucky Leap Year Discount',
        'Leap Year Discount'
      ]
    end

    def set_assignments
      Staff::Assignment.
        where(completed: false, user_id: self.user_id, reason: 'Respond').
        update(completed: true)

      true
    end

    def remove_assignments
      Staff::Assignment.
        where(completed: true, user_id: self.user_id, reason: 'Respond').
        each do |a|
          if (a.assigned_to_id == auto_worker.id) &&
             (a.assigned_by_id == auto_worker.id)
            a.destroy
          else
            a.update(unneeded: false, completed: false, unneeded_at: nil)
          end
        end

      Staff::Assignment.
        where(user_id: self.user_id, reason: 'Traveler').
        destroy_all

      true
    end

    def update_assignments
      if previous_changes.key?(:cancel_date) || previous_changes.key?("cancel_date")
        Staff::Assignment.
          where(user_id: self.user_id, reason: 'Traveler').
          update(completed: false) if self.canceled?
      end
    end

    def touch_updated_at(record)
      begin
        record.touch
      rescue
      end

      if persisted?
        self.touch
        self.user&.touch
      end
    end

  set_audit_methods!
end
