# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

# User::TravelPreparation description
class User < ApplicationRecord
  class TravelPreparation < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # attribute :joined_team_followup_date, :date
    # attribute :domestic_followup_date, :date
    # attribute :insurance_followup_date, :date
    # attribute :checklist_followup_date, :date
    # attribute :address_confirmed_date, :date
    # attribute :dob_confirmed_date, :date
    # attribute :fundraising_packet_received_date, :date
    # attribute :travel_packet_received_date, :date
    # attribute :applied_for_passport_date, :date
    # attribute :applied_for_eta_date, :date

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :travel_preparation, touch: true
    has_one :passport, through: :user, inverse_of: :travel_preparation

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_initialize :set_initial_values
    before_validation :normalize

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    class << self
      def milestones
        @milestones ||= [] |
          application_milestones |
          confirmation_milestones |
          followup_milestones |
          received_item_milestones |
          deadline_milestones |
          call_milestones |
          email_milestones
      end

      def application_milestones
        %w[
          applied_for_eta_date
          applied_for_passport_date
        ]
      end

      def confirmation_milestones
        %w[
          address_confirmed_date
          dob_confirmed_date
          name_confirmed_date
          print_name_confirmed_date
        ]
      end

      def followup_milestones
        %w[
          checklist_followup_date
          domestic_followup_date
          insurance_followup_date
          joined_team_followup_date
        ]
      end

      def received_item_milestones
        %w[
          fundraising_packet_received_date
          travel_packet_received_date
        ]
      end

      def deadline_milestones
        # disallow setting milestones from travel_preparation route
        # %w[
        #   early_payoff_deadline
        #   final_payment_deadline
        #   rollover_deadline
        #   two_thousand_deadline
        # ]
        %w[
          rollover_deadline
        ]
      end

      def call_milestones
        (
          %w[
            departure
            day_after
            week_one
            week_two
            week_three
            week_four
          ] +
          get_month_calls
        ).map do |k|
          %W[
            called_#{k}_date
            called_#{k}_type
            called_#{k}_user
          ]
        end.flatten
      end

      def email_milestones
        (
          %w[
            day_after_video
            fundraising_video
            gbr_video
            passport_video
            review_video
            tshirt_video
          ] +
          get_month_calls
        ).map do |k|
          %W[
            emailed_#{k}_date
            emailed_#{k}_type
            emailed_#{k}_user
          ]
        end.flatten
      end

      def get_month_calls
        (
          Date::MONTHNAMES.
            select(&:present?).
            map {|d| ["first_#{d.downcase}", "second_#{d.downcase}"] }
        ).flatten
      end
    end

    # == Boolean Methods ======================================================
    def normalize
      # raise "HELL"
      %i[
        followups
        confirmations
        items_received
        applications
        deadlines
        calls
      ].each do |hash|
        has_nils = false
        og = __send__(hash)
        fixed = og.dup
        og.each do |k,v|
          if v.blank?
            has_nils = true
            fixed.delete(k)
          end
        end

        __send__("#{hash}=", fixed) if has_nils
      end
    end

    def has_questions_answered?(m = :any?)
      [
        :has_aliases,
        :has_convictions,
        :has_multiple_citizenships
      ].__send__(m) {|k| selected_question?(k)}
    rescue
      false
    end

    def has_all_questions_answered?
      has_questions_answered? :all?
    rescue
      false
    end

    def selected_question?(v)
      v = self.__send__(v) if v.to_s =~ /^has_/
      BetterRecord::ThreeState.convert_to_three_state(v) != 'U'
    rescue
      false
    end

    # == Instance Methods =====================================================
    def method_missing(method_name, *arguments, &block)
      if is_proxyable_method?(method_name)
        hash_name, key_name = nil
        type = :date
        case method_name.to_s
        when /_deadline/
          key_name = method_name.to_s.sub(/_deadline=?/, '')
          hash_name = :deadlines
        when /_followup_date/
          key_name = method_name.to_s.sub(/_followup_date=?/, '')
          hash_name = :followups
        when /_confirmed_date/
          key_name = method_name.to_s.sub(/_confirmed_date=?/, '')
          hash_name = :confirmations
        when /_received_date/
          key_name = method_name.to_s.sub(/_received_date=?/, '')
          hash_name = :items_received
        when /^applied_for_/
          key_name = method_name.to_s.match(/^applied_for_(.*?)_date=?$/)[1]
          hash_name = :applications
        when /^(email|call)ed_[a-z_]+?_(date|type|user)/
          hash_type, key_name, category = method_name.to_s.match(/^(email|call)ed_([a-z_]+?)_(date|type|user)=?$/)[1..3]
          super unless category.present?
          type = (category == "date") ? :date : category.to_sym
          hash_name = (hash_type == "email") ? :emails : :calls
        else
          puts "METHOD NOT MATCHED: #{method_name}"
        end
        return super unless hash_name.present? && key_name.present?

        define_missing_attribute get_method_from_hash_and_key(hash_name, key_name, type), hash_name, key_name, type

        __send__ method_name, *arguments, &block
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      is_proxyable_method?(method_name) || super
    end

    private
      def set_json_value(hash_name, key, value, ext = :date)
        parsed_val = value.presence
        if parsed_val && (ext == :date)
          parsed_val =
            case value
            when Date
              value
            else
              Date.parse(value.to_s) rescue nil
            end
        end

        parsed_key =
          case hash_name
          when :calls, :emails
            "#{key}_#{ext}"
          else
            key
          end

        if parsed_val
          __send__(hash_name)[parsed_key] = parsed_val.to_s
        else
          __send__(hash_name).delete parsed_key
        end

        attr_key = get_method_from_hash_and_key(hash_name, key, ext)
        retries = 0

        begin
          self[attr_key] = parsed_val
        rescue ActiveModel::MissingAttributeError
          if (retries += 1) > 2
            raise
          else
            define_missing_attribute attr_key, hash_name, key, ext
            # __send__ :initialize, attributes.to_h
            retry
          end
        end

        self[attr_key] = parsed_val
      end

      def get_method_from_hash_and_key(hash_name, key, ext = :date)
        case hash_name
        when :deadlines
          :"#{key}_deadline"
        when :followups
          :"#{key}_followup_date"
        when :confirmations
          :"#{key}_confirmed_date"
        when :items_received
          :"#{key}_received_date"
        when :applications
          :"applied_for_#{key}_date"
        when :calls
          :"called_#{key}_#{ext}"
        when :emails
          :"emailed_#{key}_#{ext}"
        else
          raise "Invalid Category"
        end
      end

      def set_initial_values
        %i[
          deadlines
          followups
          confirmations
          items_received
          applications
        ].each do |hash_name|
          if self.respond_to? hash_name
            __send__(hash_name).dup.each {|k,v| set_json_value hash_name, k, v, :date }
          end
        end

        %i[
          calls
          emails
        ].each do |hash_name|
          if self.respond_to? hash_name
            __send__(hash_name).dup.each do |k, v|
              *key, cat = k.split("_")
              cat ||= :date
              set_json_value hash_name, key.join("_"), v, cat
            end
          end
        end


        self
      end

      def define_missing_attribute(attr_key, hash_name, key, ext = :date)
        type = (ext == :date) ? :date : :text

        self.class.attribute attr_key, type

        self.class.define_method attr_key do
          begin
            value = __send__(hash_name)[key].presence
            self[attr_key] ||= value.presence && (
              case type
              when :text
                value.to_s
              else
                Date.parse(value)
              end
            )
          rescue
            __send__(hash_name).delete key
            nil
          end
        end

        self.class.define_method :"#{attr_key}=" do |value|
          set_json_value hash_name, key, value, ext
        end

        @attributes[attr_key.to_s] = self.class._default_attributes.deep_dup[attr_key.to_s]

        self
      end

      def is_proxyable_method?(method_name)
        !!(method_name.to_s =~ /_deadline=?$|(_followup|_confirmed|_received|^applied_for_.*?)_date=?$|^(email|call)ed_[a-z_]+?_(date|type|user)=?$/)
      end

      def reinitialize_attributes
        og_attrs = @attributes

        @attributes = self.class._default_attributes.deep_dup

        og_attrs.to_h.each do |k,v|
          @attributes.__send__(og_attrs[k].changed? ? :write_from_user : :write_from_database, k, v)
        end

        self
      end
  end
end

# User::TravelPreparation.set_milestone_methods
