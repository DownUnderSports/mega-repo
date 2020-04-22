# encoding: utf-8
# frozen_string_literal: true

class Unsubscriber < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  attribute :email, :text

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.find_by(param, *arg)
    super(convert_params(param), *arg)
  end

  def self.convert_params(params)
    if params.is_a? Hash
      params = params.deep_symbolize_keys
      if params[:category].present?
        params[:category] = Category.convert_to_unsubscriber_category(params[:category])
        if params[:value].present?
          params[:value] = format_for_category(params[:value], params[:category])
        end
      end
      super params
    else
      params
    end
  end

  def self.format_for_category(value, category = 'E')
    if value.is_a?(Array)
      value.map {|v| format_for_category(v, category)}.flatten
    else
      case category.to_sym
      when :E
        value.to_s.downcase.split(';').map(&:strip)
      when :M
        value.to_s.downcase.gsub(/\n/, ', ')
      when :T, :C
        value.to_s.gsub(/[^0-9]/, '')
      end
    end
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def parsed_category
    self.category = self[:category] unless self[:category].to_s =~ /^[A-Z]$/
    self[:category]
  end

  def category=(cat)
    self[:category] = Category.convert_to_unsubscriber_category(cat)
  end

  def email
    parsed_category == "E" ? self.value : nil
  end

  def email=(email_val)
    self.category = 'E'
    self.value = email_val.to_s.presence&.strip&.downcase
  end

end
