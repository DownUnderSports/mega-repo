# encoding: utf-8
# frozen_string_literal: true

class Interest < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :users
  has_many :user_histories, class_name: "User::InterestHistory"

  # == Validations ==========================================================
  validates :level, presence: true,
                    uniqueness: { case_sensitive: false }

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  # == Callbacks ============================================================
  before_save :format_level

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.reset_cached_levels
    %i[
      Curious
      Interested
      Never
      MaybeNextYear
      NextYear
      NoRespond
      NotGoing
      OpenTryout
      Restricted
      SendingDeposit
      SupporterNotGoing
      Traveling
      Unknown
      ContactableNextYear
    ].each {|k| self.__send__ :remove_const, k rescue nil }
    @interest_levels = {}
    @interest_is_contactable = {}
    @interest_id_from_level = {}
  end

  def self.level(id)
    @interest_levels ||= {}
    @interest_levels[id] ||= find_by(id: id)&.level.to_s
  end

  def self.contactable(id)
    @interest_is_contactable ||= {}
    @interest_is_contactable[id] ||= !!((find_by(id: id) || find_by(level: id.to_s.titleize))&.contactable)
  end

  def self.contactable_ids
    Interest.where(contactable: true).pluck(:id)
  end

  def self.get_id(level)
    @interest_id_from_level ||= {}
    @interest_id_from_level[level] ||=
      begin
        self.const_get(level.to_s.classify.to_sym).id
      rescue
        find_by(level: level.to_s.titleize)&.id
      end
  end

  def self.get(key)
    self.find(self.get_id(key) || key)
  end

  def self.restricted
    get_id :never
  end

  def self.const_missing(name)
    case name
    when :Curious
      const_set name, self.find_by(level: "Curious")
    when :Interested
      const_set name, self.find_by(level: "Interested")
    when :OpenTryout
      const_set name, self.find_by(level: "Open Tryout")
    when :Never, :Restricted
      const_set name, self.find_by(level: "Never")
    when :NextYear, :MaybeNextYear
      const_set name, self.find_by(level: "Next Year")
    when :NoRespond
      const_set name, self.find_by(level: "No Respond")
    when :NotGoing
      const_set name, self.find_by(level: "Not Going")
    when :SendingDeposit
      const_set name, self.find_by(level: "Sending Deposit")
    when :SupporterNotGoing
      const_set name, self.find_by(level: "Supporter - Not Going")
    when :Traveling
      const_set name, self.find_by(level: "Traveling")
    when :Unknown
      const_set name, self.find_by(level: "Unknown")
    when :ContactableNextYear
      const_set name, [ NextYear, NoRespond ]
    else
      super
    end
  end

  # == Boolean Methods ======================================================
  def contactable_next_year?
    self.contactable? || self.in?(ContactableNextYear)
  end

  # == Instance Methods =====================================================

  private
    def format_level
      self.level = level.to_s.titleize
    end
end
