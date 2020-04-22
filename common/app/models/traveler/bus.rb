# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

# Traveler::Bus description
class Traveler < ApplicationRecord
  class Bus < ApplicationRecord
    # == Constants ============================================================
    def self.const_missing(name)
      case name
      when :Brumbies, :Gold
        const_set name, { color: :Gold, name: :Brumbies }.freeze
      when :Crocodiles, :Green
        const_set name, { color: :Green, name: :Crocodiles }.freeze
      when :Dingoes, :Blue
        const_set name, { color: :Blue, name: :Dingoes }.freeze
      when :Emus, :Purple
        const_set name, { color: :Purple, name: :Emus }.freeze
      when :Kangaroos, :Red
        const_set name, { color: :Red, name: :Kangaroos }.freeze
      when :Koalas, :White
        const_set name, { color: :White, name: :Koalas }.freeze
      when :Kookaburras, :Yellow
        const_set name, { color: :Yellow, name: :Kookaburras }.freeze
      when :Lorikeets, :Silver
        const_set name, { color: :Silver, name: :Lorikeets }.freeze
      when :Wallabies, :Pink
        const_set name, { color: :Pink, name: :Wallabies }.freeze
      when :Wombats, :Orange
        const_set name, { color: :Orange, name: :Wombats }.freeze
      else
        super
      end
    end

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.traveler_buses"
    attribute :combo

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :sport, inverse_of: :buses
    belongs_to :hotel, class_name: 'Traveler::Hotel', inverse_of: :buses, optional: true

    has_and_belongs_to_many :travelers, inverse_of: :buses, after_add: :touch_updated_at, after_remove: :touch_updated_at do
      def athletes
        joins(:user).where(users: { category_type: :athletes })
      end

      def coaches
        joins(:user).where(users: { category_type: :coaches })
      end

      def others
        joins(:user).where.not(users: { category_type: [ nil, :coaches, :athletes ] })
      end

      def supporters
        joins(:user).where(users: { category_type: nil })
      end
    end

    # == Validations ==========================================================
    validates_presence_of :color, :name
    validates_uniqueness_of :sport_id, scope: [ :color, :name ]

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_combo

    before_save :check_active_year
    before_destroy :check_active_year
    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.combos
      [
        %i[ Brumbies    Gold   ].freeze,
        %i[ Crocodiles  Green  ].freeze,
        %i[ Dingoes     Blue   ].freeze,
        %i[ Emus        Purple ].freeze,
        %i[ Kangaroos   Red    ].freeze,
        %i[ Koalas      White  ].freeze,
        %i[ Kookaburras Yellow ].freeze,
        %i[ Lorikeets   Silver ].freeze,
        %i[ Wallabies   Pink   ].freeze,
        %i[ Wombats     Orange ].freeze,
      ].freeze
    end

    def self.default_print
      %i[
        id
        sport_abbr
        hotel_name
        color
        name
      ].freeze
    end

    # == Boolean Methods ======================================================

    # == Relationship Methods =================================================
    def athletes
      travelers.athletes
    end

    def athlete_users
      athletes.map(&:user)
    end

    def coaches
      travelers.coaches
    end

    def coach_users
      coaches.map(&:user)
    end

    def others
      travelers.others
    end

    def other_users
      others.map(&:user)
    end

    def supporters
      travelers.supporters
    end

    def supporter_users
      supporters.map(&:user)
    end

    # == Instance Methods =====================================================
    def to_str
      "#{self.sport.abbr_gender} - #{self.name} (#{self.color})"
    rescue
      ''
    end

    def underscored
      "#{self.sport.abbr_gender}_#{self.name}_#{self.color}"
    rescue
      ''
    end

    def coach_names
      names = travelers.coaches.map(&:user).map(&:basic_name).sort
      names.join(", ").sub(/, ([^,]+)$/, ' and \1')
    end

    def combo=(value)
      self[:combo] = get_combo(value)
      self[:color] = self[:combo][:color]
      self[:name] = self[:combo][:name]
    rescue
      self[:color] = self[:name] = nil
    end

    def combo
      self[:combo] || (self.combo = get_combo(self[:name].presence || self[:color].presence))
    rescue
      {}
    end

    def color=(value)
      self.combo = value
    rescue
      self.color
    end

    def color
      self.combo[:color]
    rescue
      nil
    end

    def hotel_name
      hotel&.name
    end

    def name=(value)
      self.combo = value
    rescue
      self.name
    end

    def name
      self.combo[:name]
    rescue
      nil
    end

    def sport_abbr
      sport&.abbr_gender
    end

    def get_combo(value = nil)
      if value.is_a?(Hash)
        value = value.with_indifferent_access
        value = value[:name].presence || value[:color]
      end

      self.class.const_get(value.to_s.titleize.to_sym)
    end

    def check_combo
      self.combo
    rescue
      errors.add("Invalid sport - name - color combo")

      self[:color] = self[:name] = nil

      throw :abort
    end

    def touch_updated_at(traveler = nil)
      begin
        traveler&.touch
        traveler&.user&.touch
      rescue
      end
      self.touch if persisted?
    end

    set_audit_methods!
  end
end
