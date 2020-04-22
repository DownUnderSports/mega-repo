# encoding: utf-8
# frozen_string_literal: true

module Filterable
  extend ActiveSupport::Concern

  # == Modules ============================================================
  GetFilterValue ||= Struct.new(:executed, :prefix, :param, :value, :options, :not_like, :separator) do
    def result
      @result
    end

    def result=(v)
      @result = v
    end

    def before
      self.result = yield(prefix, param, value, options, not_like, separator) if block_given? && !executed
    end

    def after
      self.result = yield(prefix, param, value, options, not_like, separator) if block_given? && executed
    end
  end

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================

  # == Actions ============================================================

  # == Cleanup ============================================================

  # == Utilities ==========================================================

  private
    def execute_filter_block(*args)
      helper = GetFilterValue.new(*args)
      yield helper
      !!helper.result
    end

    def param_to_col_name(param)
      param
    end

    def filter_records(**opts, &block)
      not_like = nil
      options = { filter: nil }
      allowed = whitelisted_filter_params

      allowed.each do |param, value|
        next unless value.present?
        separator = options[:filter] ? +' AND ' : +''
        options[:filter] ||= +''
        if value =~ /\|\||\&\&/
          sub_opts = { filter: nil }
          a_z = ('A'..'Z').to_a
          splitter = nil,
          sep_val = nil
          if value =~ /&&/
            splitter = '&&'
            sep_val = +' AND '
          else
            splitter = '||'
            sep_val = +' OR '
          end
          value.split(splitter).map(&:strip).each_with_index do |sub_val, i|
            next unless sub_val.present?
            sub_sep = sub_opts[:filter] ? sep_val : +''
            sub_opts[:filter] ||= +''
            get_column_filter(sub_opts, param, sub_val, sub_sep, "#{a_z[i]}_", **opts, &block)
          end
          p sub_opts
          options[:filter] << "#{separator}(#{sub_opts[:filter]})"
          options.merge!(sub_opts.except(:filter))
        else
          get_column_filter(options, param, value, separator, **opts, &block)
        end
      end

      return options.delete(:filter), options
    end

    def get_column_filter(options, param, value, separator, prefix = '', datetime_regex: /[a-z]+_at$/, date_regex: /_date$/, integer_regex: /(_count|_offset|_id)$/, boolean_regex: nil, amount_regex: nil, interval_regex: nil, utc_dates: false)
      not_like = false
      null = false
      if value.to_s =~ /^!/
        not_like = true
        value = value.to_s.sub('!', '')
      end

      case true
      when value.to_s.empty? || value.to_s.upcase == 'NULL'
        options[:filter] << "#{separator}(#{param_to_col_name(param)} IS #{not_like ? 'NOT ' : ''}NULL)"
      when block_given? && execute_filter_block(false, prefix, param, value, options, not_like, separator) {|runner| yield runner }
        true
      when boolean_regex.present? && !!(param.to_s =~ boolean_regex)
        options[:filter] << "#{separator}(#{param_to_col_name(param)} = '#{Boolean.parse(value) ? 't' : 'f'}')"
      when amount_regex.present? && !!(param.to_s =~ amount_regex)
        direction = false
        if value.to_s =~ /^[><]/
          not_like = false
          direction = value.to_s.gsub(/[^><=]/, '').strip
          value = value.to_s.sub(/^[^0-9]+/, '')
        end

        f_type = direction ? '::integer' : '::text'
        options[:filter] << "#{separator}(#{param_to_col_name(param)}#{f_type} #{direction || 'ilike'} :#{prefix}#{param}#{f_type})"
        if direction
          options["#{prefix}#{param}"] = StoreAsInt::Money.new(value.to_s.gsub(/[^0-9.]/, '')).to_i
        else
          options["#{prefix}#{param}"] = "%#{value.to_s.gsub(/[^0-9]/, '')}%"
        end
      when date_regex.present? && !!(param.to_s =~ date_regex)
        begin
          direction = false
          if value.to_s =~ /^[><]/
            not_like = false
            direction = value.to_s.gsub(/[^><=]/, '').strip
            value = value.to_s.sub(/^[^0-9]+/, '')
          end

          direction = direction.presence || '='

          options[:filter] << "#{separator}(#{not_like ? 'NOT ' : ''}#{param_to_col_name(param)} #{direction} :#{prefix}#{param})"
          options["#{prefix}#{param}"] = (utc_dates ? Time.find_zone('UTC').parse(value) : Time.zone.parse(value)).to_date
        rescue ArgumentError
          options[:filter] << "#{separator}(1 = 0)"
        end
      when datetime_regex.present? && !!(param.to_s =~ datetime_regex)
        begin
          direction = false
          if value.to_s =~ /^[><]/
            not_like = false
            direction = value.to_s.gsub(/[^><=]/, '').strip
            value = value.to_s.sub(/^[^0-9]+/, '')
          end

          dt = utc_dates ? Time.find_zone('UTC').parse(value) : Time.zone.parse(value)

          if direction
            options[:filter] << "#{separator}(#{not_like ? 'NOT ' : ''}#{param_to_col_name(param)} #{direction} :#{prefix}#{param})"
            options["#{prefix}#{param}"] = case direction
              when '>=', '<'
                dt.midnight
              else
                dt.end_of_day
              end
          else
            options[:filter] << "#{separator}(#{param_to_col_name(param)} #{not_like ? 'NOT ' : ''}BETWEEN :#{prefix}#{param}_start AND :#{prefix}#{param}_end)"
            options["#{prefix}#{param}_start"] = dt.midnight
            options["#{prefix}#{param}_end"] = dt.end_of_day
          end
        rescue ArgumentError
          options[:filter] << "#{separator}(1 = 0)"
        end
      when integer_regex.present? && !!(param.to_s =~ integer_regex) && !!(value.to_s =~ /^[><]/)
        value = value.to_s
        direction = value.gsub(/[^><=]/, '').strip
        value = value.gsub(/^[^0-9-]+/, '').strip.to_i

        if direction.present?
          options[:filter] << "#{separator}(#{param_to_col_name(param)} #{direction} :#{prefix}#{param})"
          options["#{prefix}#{param}"] = value
        else
          options[:filter] << "#{separator}(1 = 0)"
        end
      when interval_regex.present? && !!(param.to_s =~ interval_regex) && !!(value.to_s =~ /^[><]/)
        value = value.to_s
        direction = value.gsub(/[^><=]/, '').strip
        value = value.gsub(/^[^0-9:]+/, '').strip.to_i

        if direction.present?
          options[:filter] << "#{separator}(#{param_to_col_name(param)}::INTERVAL #{direction} (:#{prefix}#{param}::INTEGER || ' seconds')::INTERVAL)"
          options["#{prefix}#{param}"] = value
        else
          options[:filter] << "#{separator}(1 = 0)"
        end
      when (block_given?) && execute_filter_block(true, prefix, param, value, options, not_like, separator) {|runner| yield runner }
        true
      else
        value = value.to_s.upcase.sub('-', '') if param.to_s =~ /dus/
        if value.to_s =~ /^=/
          options[:filter] << "#{separator}(#{param_to_col_name(param)}::text #{not_like ? '<>' : '='} :#{prefix}#{param})"
          options["#{prefix}#{param}"] = value.to_s.sub(/^=/, '')
        else
          options[:filter] << "#{separator}(#{param_to_col_name(param)}::text #{not_like ? 'NOT ' : ''}ILIKE :#{prefix}#{param})"
          options["#{prefix}#{param}"] = "%#{value}%"
        end
      end
    end
end
