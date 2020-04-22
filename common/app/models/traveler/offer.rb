# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class Offer < ApplicationRecord
    # == Constants ============================================================
    RULE_TYPES = %w[
      alternate
      balance
      credit
      debit
      deposit
      destroy
      offer
      payment
      percentage
      signup
      placeholder
      share
    ].freeze

    # == Attributes ===========================================================
    self.primary_key = "id"
    # self.table_name = "#{usable_schema_year}.traveler_offers"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :offers, touch: true
    belongs_to :assigner, class_name: 'User', optional: true

    has_one :traveler, through: :user

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_commit :run_check_on_create, on: :create

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================
    def is_credit?
      rule == 'credit'
    end

    def is_debit?
      rule == 'debit'
    end

    def is_offer?
      rule == 'offer'
    end

    def is_rule?
      rule.in? RULE_TYPES
    end

    def should_destroy?
      rule == 'destroy'
    end

    def has_alternate?
      rules.any? 'alternate'
    end

    # == Instance Methods =====================================================
    def materialize
      if dbt = debit
        if og_dbt = traveler.debits.find_by(base_debit_id: dbt.base_debit_id)
          og_dbt.update(amount: dbt.amount, name: dbt[:name].presence, description: dbt[:description].presence)
        else
          traveler.debits << dbt
        end
        next_rule
      elsif cdt = credit
        traveler.credits.where(name: cdt.name).destroy_all
        traveler.credits << cdt
        next_rule
      elsif values = offer
        self.update(values) && self.class.find_by(id: self.id)&.__send__(values[:rules].present? ? :run_check : :next_rule)
      elsif rule == 'percentage'
        earned = percentage_amount
        traveler.credits.where(name: name).destroy_all
        value = [[earned, [700_00.cents, maximum].max - traveler.total_main_credits].min, 0].max
        traveler.credits << Credit.new(amount: value, name: name, description: description, assigner: assigner) if value > 0
        (earned >= maximum) && next_rule
      else
        traveler.offers.reload

        if amount.present? && amount > 0.cents
          traveler.credits.destroy_all if amount.value > 500_00

          traveler.credits << Credit.new(amount: amount, name: name, description: description, assigner: assigner)
        end

        next_rule
      end
    end

    def payments_since_creation
      StoreAsInt.money traveler.items.successful.where('payment_items.created_at >= ?', created_at).sum(:amount)
    end

    def percentage_amount
      if minimum.blank? || (value = payments_since_creation) > minimum
        [(((payments_since_creation - minimum.to_i) * amount) / 100.to_d), maximum].min.to_i
      else
        0
      end
    end

    def recreate
      if rules[1..-1].present?
        next_rule
      else
        traveler.credits.where(name: name).destroy_all
        traveler.credits.create!(name: name, description: description, amount: amount, assigner: assigner)
        destroy!
      end
    end

    def rule
      rules.first
    end

    def run_check(*args)
      self.with_lock do
        if expiration_date && (expiration_date < Date.today)
          if has_alternate?
            self.rules = self.rules[self.rules.index('alternate')..-1]
            next_rule(true)
          else
            self.destroy
          end
        else
          unless is_offer? || should_destroy? || traveler
            self.updated_at = Time.zone.now
            return save!
          end

          case rule
          when 'credit', 'debit', 'offer', 'percentage'
            materialize
          when 'alternate', 'destroy'
            destroy
          when 'balance'
            materialize if traveler.total_payments &.>= minimum
          when 'deposit'
            recreate if traveler.deposit.present?
          when 'payment'
            materialize if payments_since_creation &.>= minimum
          when 'signup'
            recreate if traveler.first_payment.present?
          when 'share'
            copy_to_relations if traveler
          else
            self.updated_at = Time.zone.now
            save!
          end
        end
      end
    end

    private
      def copy_to_relations(move = true)
        o = self.dup
        o.rules = o.rules[1..-1] if rules[0] == 'share'
        user.related_users.each do |u|
          u.offers << o.dup
        end
        next_rule if move
      end

      def credit
        is_credit? && Credit.new(rule_hash)
      end

      def debit
        is_debit? && Debit.new(rule_hash)
      end

      def offer
        is_offer? && rule_hash
      end

      def get_date(exp)
        case (exp = exp.presence.to_s)
        when /^\d{4}-\d{2}-\d{2}$/
          return exp.to_date
        when /^deposit/
          (traveler&.deposit_date || Date.today) +
          get_days_from_string(exp)
        when /^signup/
          (traveler&.first_payment_date || Date.today) +
          get_days_from_string(exp)
        when /^now/
          Time.zone.now + get_days_from_string(exp)
        when /^(\:*[A-Z]+[a-z]+)+\[(.*)\]\[(.*)\]/
          id, col, days = exp.match(/^(\:*[A-Z]+[a-z]+)+\[(.*)\]\[(.*)\]-?(\d+)?/).to_a[2..-1]
          model = exp.match(/^(\:*[A-Z]+[a-z]+)+/).to_s
          (model&.constantize&.find(id)&.__send__(col) || Date.today).to_date + days.to_i
        else
          Date.today + get_days_from_string(exp)
        end
      end

      def get_days_from_string(str)
        (str.gsub(/[^0-9]/, '').presence&.to_i || 30).days
      end

      def next_rule(is_alternate = false)
        loop do
          self.rules.shift
          break if (self.rules.blank? || is_rule?)
        end

        if self.rules.blank?
          destroy
        else
          save! && reload && ((is_alternate && is_offer?) ? materialize : run_check)
        end
      end

      def rule_hash
        values = JSON.parse(rules.second).to_h.deep_symbolize_keys
        values.dup.each do |k, v|
          values[k] = get_date(v) if v.present? && (k.to_s =~ /(date|_at)$/)
        end
        values
      end

      def run_check_on_create
        self.class.find_by(id: self.id)&.run_check && user.offers.reload
        true
      end

    set_audit_methods!
  end
end
