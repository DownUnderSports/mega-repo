# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class UniformOrder < ApplicationRecord
    # == Constants ============================================================
    NON_DUPABLE_KEYS = Set.new(%i[ cost submitted_to_shop_at paid_shop_at invoice_date shipped_date ])

    # PresenceAndFormatValidator
    # ShippingValidator
    # UNIFORM_BY_SPORT

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :sport, inverse_of: :uniform_orders
    belongs_to :user, inverse_of: :uniform_orders, touch: true
    belongs_to :submitter, class_name: 'User', inverse_of: :submitted_uniform_orders

    # == Validations ==========================================================
    validates :jersey_size,
              presence_and_format:  true,
              unless: ->(order) do
                        order.is_reorder \
                        && order.shorts_size.present? \
                        && order.jersey_size.blank?
                      end

    validates :shorts_size,
              presence_and_format:  true,
              unless: ->(order) do
                        (
                          order.is_reorder \
                          && order.jersey_size.present? \
                          && order.shorts_size.blank?
                        ) \
                        || (order.sport&.abbr == 'GF')
                      end

    validate :preferred_numbers_exist,
              unless: ->(order) do
                        order.is_reorder \
                        && order.jersey_size.blank?
                      end

    validates :shipping, shipping: true

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_validation :get_sport
    after_commit :send_to_it, on: :create

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.available
      joins(user: { traveler: :team }).
      where(submitted_to_shop_at: nil).
      where(travelers: { cancel_date: nil }).
      order(Arel.sql('COALESCE(travelers.departing_date, teams.departing_date)'), :id)
    end

    def self.assign_numbers(sport_id)
      errors = []
      transaction do
        q = self.
          joins(user: :traveler).
          order(:id).
          where(sport_id: sport_id, travelers: { cancel_date: nil })

        q.where(sport_id: Sport::FB.id).each do |uo|
          errors << uo.user.admin_url unless uo.user.traveler.competing_teams.find_by(sport_id: sport_id)
        end

        raise "Unassigned Travelers" unless errors.blank?

        q.where(jersey_number: nil).each do |uo|
          if uo.sport.abbr == 'FB'
            j_num = nil
            %i[
              preferred_number_1
              preferred_number_2
              preferred_number_3
            ].each do |m|
              j_num = uo.__send__(m).presence&.to_i
              if j_num
                found = uo.class.joins(user: :traveler).order(:id).where(jersey_number: j_num, sport_id: uo.sport_id, travelers: { cancel_date: nil })

                break if found.empty?

                ct = nil

                raise "TEAM NOT FOUND FOR JERSEY NUMBER: #{j_num} (Order ID: #{uo.id}, DUS ID: #{uo.user&.dus_id})" unless [
                  *(found.to_a),
                  uo
                ].all? do |co|
                  ct = co.user&.traveler&.competing_teams&.find_by(sport_id: uo.sport_id)
                end


                unless (sub_f = found.where(travelers: { id: ct.travelers.select(:id) })).empty?
                  errors << "#{uo.id}:#{uo.user.traveler.competing_teams_string} - #{j_num} - #{sub_f.pluck(:id).join(',')}:#{sub_f.map(&:user).map(&:traveler).map(&:competing_teams_string).join(',')}"
                  j_num = nil
                end

              end
              break if j_num
            end
            if j_num.present?
              uo.update!(jersey_number: j_num.to_i)
            else
              errors << uo.user.admin_url
            end
          else
            # find_gaps
            # i = 1
            # numbers = q.where(sport_id: uo.sport_id).pluck(:jersey_number).map {|v| [v, 1]}.to_h.freeze
            # i += 1 while numbers[i]
            # uo.update(jersey_number: i)

            # O(1) execution
            uo.update(jersey_number: q.where(sport_id: uo.sport_id).maximum(:jersey_number).to_i + 1) unless uo.sport.in? [ Sport::TF, Sport::XC, Sport::GF, Sport::CH ]
          end
        end
      end
      errors
    rescue
      errors << $!.message
      errors << $!.backtrace
      errors.flatten
    end

    def self.create_bulk_order_csv(sport_id)
      csv_file = nil
      transaction do
        csv_file = CSV.generate(encoding: 'UTF-8', force_quotes: true) do |csv|
          csv << %w[ name po_number state state_full sport sport_full jersey_number item_type item_number item_color item_size ]
          assign_numbers(sport_id) if sport_id.is_a?(Integer) || (sport_id.is_a?(String) && (sport_id =~ /^[0-9]+$/))
          available.where(sport_id: sport_id).order(:id).split_batches do |b|
            b.each do |o|
              raise "NO JERSEY NUMBER" if o.jersey_size.present? && o.jersey_number.nil? && o.sport.abbr.in?(%w[ BB VB FB ])

              o.update! submitted_to_shop_at: Time.zone.now
              base_csv = [
                o.shipping['name'],
                o.id + 1000,
                o.user&.team&.state&.abbr || o.shipping['state_abbr'],
                State[o.user&.team&.state&.abbr || o.shipping['state_abbr']]&.full,
                o.sport.abbr_gender,
                o.sport.full_gender,
              ]

              if o.jersey_size.present?
                o.jersey_count.times do
                  jersey_csv = [
                    *base_csv,
                    o.jersey_number,
                    (o.sport.abbr == "GF" ? 'Polo' : 'Jersey'),
                    o.jersey_size_details[:number],
                    o.jersey_size_details[:color],
                    o.jersey_size.gsub(/[WM]-/i, '')
                  ]

                  csv << jersey_csv

                  if o.two_color?
                    jersey_csv[-2] = o.jersey_size_details[:color_2]
                    csv << jersey_csv
                  end
                end
              end
              if o.shorts_size.present?
                o.shorts_count.times do
                  csv << [
                    *base_csv,
                    nil,
                    (o.sport.abbr == "FB" ? 'Pants' : 'Shorts'),
                    o.shorts_size_details[:number],
                    o.shorts_size_details[:color],
                    o.shorts_size.gsub(/[WM]-/i, '')
                  ]
                end
              end
            end
          end
        end
      end
      csv_file.presence || ''
    rescue
      puts $!.message, $!.backtrace
      ''
    end

    def self.create_stamps_csv(sport_id = nil, order_date = nil)
      p "sport: #{sport_id}, date: #{order_date}"
      csv_file = nil
      transaction do
        time = order_date.presence && Time.zone.parse(order_date)
        csv_file = CSV.generate(encoding: 'UTF-8', force_quotes: true) do |csv|
          csv << [
            'Order ID (required)',
            'Order Date',
            'Order Value',
            'Requested Service',
            'Ship To - Name',
            'Ship To - Company',
            'Ship To - Address 1',
            'Ship To - Address 2',
            'Ship To - Address 3',
            'Ship To - State/Province',
            'Ship To - City',
            'Ship To - Postal Code',
            'Ship To - Country',
            'Ship To - Phone',
            'Ship To - Email',
            'Total Weight in Oz',
            'Dimensions - Length',
            'Dimensions - Width',
            'Dimensions - Height',
            'Notes - From Customer',
            'Notes - Internal',
            'Gift Wrap?',
            'Gift Message'
          ]

          p q = sport_id.present? \
            ? where(sport_id: sport_id) \
            : all

          q = time.present? \
            ? q.where(%Q(submitted_to_shop_at BETWEEN :start_time AND :end_time), start_time: time.midnight, end_time: time.end_of_day) \
            : q.where.not(submitted_to_shop_at: nil)

          q.order(:id).split_batches do |b|
            b.each do |o|
              csv << [
                "uniform_order.#{o.sport.abbr}.#{o.id + 1000}",
                o.submitted_to_shop_at.to_date.to_s,
                o.price.to_s,
                o.shipping_service,
                o.shipping['name'],
                nil,
                o.shipping['street_1'].presence,
                o.shipping['street_2'].presence,
                o.shipping['street_3'].presence,
                o.shipping['state_abbr'].presence,
                o.shipping['city'].presence,
                o.shipping['zip'].presence,
                'USA',
                nil,
                'it@downundersports.com',
                nil,
                nil,
                nil,
                nil,
                "#{o.sport.abbr}#{o.id + 1000}",
                "#{o.user.dus_id}.#{o.sport.abbr_gender}.#{o.id}",
                "FALSE",
                nil
              ]
            end
          end
        end
      end
      csv_file.presence || ''
    rescue
      puts $!.message, $!.backtrace
      ''
    end

    def self.default_print
      [
        :id,
        :user_id,
        :jersey_size,
        :shorts_size,
        :jersey_number,
        :preferred_number_1,
        :preferred_number_2,
        :preferred_number_3,
        :submitted_to_shop_at,
        :shipped_date,
        :invoice_date,
      ]
    end

    def self.find_missing(sport_id)
      sport = Sport[sport_id]
      missing = []
      Traveler.active do |t|
        next if t.user_id.in? test_user_environment_ids

        next unless t.user.is_athlete? && t.competing_in?(sport)

        unless t.user.uniform_orders.find_by(sport_id: sport.id)
          missing << t.departing_date
          missing << t.team.state.abbr
          missing << t.team.sport.abbr_gender
          missing << t.user.athlete_and_parent_emails.join(';')
          missing << t.user.athlete_and_parent_phones.join(';')
          missing << t.user.admin_url
          missing << "#{t.user.hash_url('uniform-order')}/#{sport.abbr_gender}"
          missing << nil
        end
      end
      missing
    rescue
      []
    end

    def self.sent
      where.not(submitted_to_shop_at: nil)
    end

    def self.summary
      summarized = {}
      Sport.order(:full, :full_gender).each do |sport|
        sport_orders = sent.
          joins(:user).
          where(sport_id: sport.id).
          group(:sport_id).
          select(
            %Q(COUNT(#{table_name}.id) AS order_count),
            :sport_id,
            %Q(MIN(#{table_name}.user_id) AS user_id)
          )

        [:jersey_size, :shorts_size].each do |cat|
          summarized[cat] ||= {}
          other = cat == :jersey_size ? :shorts_size : :jersey_size

          sport_orders.
          group(cat).
          order(cat).
          select(
            %Q(MIN(#{other}) AS #{other}),
            cat
          ).each do |order_group|
            next unless order_group.__send__(cat).present?
            details = order_group.__send__("#{cat}_details")

            summarized[cat][details[:number]] ||= {
              "description" => details[:description],
              "fb" => (cat == :jersey_size) && sport.abbr == 'FB',
              "color" => details[:color],
              "sizes" => {}
            }

            summarized[cat][details[:number]]['sizes'][order_group[cat].to_s.gsub(/[WM]-/i, '')] ||= 0

            summarized[cat][details[:number]]['sizes'][order_group[cat].to_s.gsub(/[WM]-/i, '')] += order_group.order_count
          end
        end
      end
      summarized
    end

    # == Boolean Methods ======================================================
    def is_football?
      get_sport&.abbr == 'FB'
    end

    def two_color?
      !!jersey_size_details[:color_2]
    end

    def missing_fields?
      missing_jersey_number? || missing_sport?
    end

    def missing_jersey_number?
      jersey_number.blank? && preferred_number_1.present?
    end

    def missing_numbers?
      (1..3).any? {|num| self.__send__("preferred_number_#{num}").blank? }
    end

    def missing_sport?
      (sport_id.blank? && self.sport_id.blank?) && !!get_sport
    end

    def numbers_unique?
      (1..3).none? do |num|
        p_num = self.__send__("preferred_number_#{num}").to_i
        (1..3).any? {|sub_num| (sub_num != num) && (p_num == self.__send__("preferred_number_#{sub_num}").to_i) }
      end
    end

    # == Instance Methods =====================================================
    def get_gender(str)
      ((match = str.to_s.match(/([MW])-/i)) ? match[1] : (user&.gender&.upcase == "F" ? 'W' : 'M')).upcase.to_sym
    end

    def shipping_service
      @shipping_service ||= UNIFORM_BY_SPORT[get_sport.abbr.to_sym][:shipping_service] || 'Priority Mail Flat Rate Envelope'
    end

    def get_shop_details
      details = UNIFORM_BY_SPORT[get_sport.abbr.to_sym]

      has_prefix = !!((jersey_size.present? ? jersey_size : shorts_size) =~ /^[MW]-/)

      @sport_provider   = details[:provider] || :badger
      @shipping_service = details[:shipping_service] || 'Priority Mail Flat Rate Envelope'

      @jersey_size_details = has_prefix ? details[get_gender(jersey_size)][:jersey] : details[:jersey]
      if @jersey_size_details
        @jersey_size_details = (jersey_size.present? && @jersey_size_details[jersey_size.upcase.to_sym]) || @jersey_size_details
      else
        @jersey_size_details = {}
      end

      @shorts_size_details = (has_prefix ? details[get_gender(shorts_size)][:shorts] : details[:shorts]) || {}
      [@jersey_size_details, @shorts_size_details, @sport_provider]
    end


    def get_sport
      self.sport ||= user&.team&.sport
    end

    def jersey_count
      if jersey_size.present?
        self[:jersey_count] = (self[:jersey_count] < 1) ? 1 : self[:jersey_count]
      else
        self[:jersey_count] = 0
      end
    end

    def jersey_size_details
      return @jersey_size_details || get_shop_details[0]
    end

    def price
      self.cost = get_cost unless Boolean.parse(self.cost)
      return self.cost
    end

    def replacement_cost
      (jersey_size_details[:cost] * (two_color? ? 2 : 1) * jersey_count) \
        + (shorts_size_details[:cost] * shorts_count) \
        + 15_00
    rescue
      0
    end

    def shipping_label
      shipping_str = "#{shipping['name']}"
      %w[
        street_1
        street_2
        street_3
      ].each {|k| shipping_str += "\n#{shipping[k]}" if shipping[k].present?}
      shipping_str += "\n#{shipping['city']}, #{shipping['state_abbr']} #{shipping['zip']}"
      shipping_str
    end

    def shorts_count
      if shorts_size.present?
        self[:shorts_count] = (self[:shorts_count].to_i < 1) ? 1 : self[:shorts_count]
      else
        self[:shorts_count] = 0
      end
    end

    def shorts_size_details
      @shorts_size_details || get_shop_details[1]
    end

    def sport_provider
      @sport_provider ||= UNIFORM_BY_SPORT[get_sport.abbr.to_sym][:provider] || :badger
    end

    private
      def preferred_numbers_exist
        if sport&.is_numbered && (missing_numbers? || !numbers_unique?)
          errors.add(:base, "3 unique preferred numbers are required")
        end
      end

      def clear_uniform_messages
        self.user.remove_missing_messages
      end

      def send_to_it
        UniformMailer.received(self.id).deliver_later
      end

      def send_to_shop
        save_price!
        UniformMailer.place(self.id).deliver_later
      end

      def save_price!
        price && save!
      end

      def get_cost
        (jersey_size_details[:price] * (two_color? ? 2 : 1) * jersey_count) \
          + (shorts_size_details[:price] * shorts_count) \
          + (sport_provider == :badger ? 2_00 : 0)
      rescue
        0
      end

    set_audit_methods!
  end
end
