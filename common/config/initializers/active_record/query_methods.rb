module ActiveRecord
  class Relation
    unless MULTI_VALUE_METHODS.include? :default_order
      MULTI_VALUE_METHODS << :default_order
      VALUE_METHODS << :default_order
    end
    class Merger
      def merge_multi_values
        if other.reordering_value
          # override any order specified in the original relation
          relation.reorder!(*other.order_values)
        elsif other.order_values.any?
          # merge in order_values from relation
          relation.order!(*other.order_values)
        elsif other.default_order_values.any?
          relation.default_order!(*other.default_order_values)
        end

        extensions = other.extensions - relation.extensions
        relation.extending!(*extensions) if extensions.any?
      end
    end

    alias :full_explain :explain

    def explain(format = nil)
      result = ActiveRecord::Base.connection.exec_query(Arel.sql("EXPLAIN#{format ? ' (analyze, format yaml)' : '' } #{self.to_sql}"), "EXPLAIN")

      header = result.columns.first
      lines  = format ? result.rows.first.first.split("\n") : result.rows.map(&:first)

      # We add 2 because there's one char of padding at both sides, note
      # the extra hyphens in the example above.
      width = [header, *lines].map(&:length).max + 2

      pp = []

      pp << header.center(width).rstrip
      pp << "-" * width

      pp += lines.map { |line| " #{line}" }

      nrows = lines.size
      rows_label = nrows == 1 ? "row" : "rows"
      pp << "(#{nrows} #{rows_label})"

      pp.join("\n") + "\n"
    end
  end

  module QueryMethods
    DEFAULT_VALUES[:default_order] = FROZEN_EMPTY_ARRAY
    VALID_UNSCOPING_VALUES << :default_order

    module QueryFormatter
      def self.value_unless_string(value)
        if value.is_a?(String)
          yield
        else
          value
        end
      end

      def self.upcase_presence(value)
        value_unless_string(value) do
          value.presence&.upcase&.strip
        end
      end

      QUERY_FORMATTERS = {
        dus_id:       ->(dus_id) do
                        value_unless_string(dus_id) do
                          User.forwardable(dus_id.dus_id_format)
                        end
                      end,
        pid:          ->(pid) do
                        value_unless_string(pid) do
                          pid.presence&.pid_format
                        end
                      end,
        gender:       ->(gender) { upcase_presence(gender)&.first },
        code:         ->(code) { upcase_presence(code) },
        pnr:          ->(pnr) { upcase_presence(pnr) },
        abbr:         ->(abbr) do
                        value_unless_string(abbr) do
                          abbr.abbr_format
                        end
                      end,
        abbr_gender:  ->(abbr_gender) do
                        value_unless_string(abbr_gender) do
                          abbr_gender.abbr_format
                        end
                      end
      }.freeze
    end

    alias :super_unscope! :unscope!

    def unscope!(*args)
      args << :default_order if args.include?(:order)
      super_unscope! *args
    end

    def default_order_values
      get_value(:default_order)
    end

    def default_order_values=(value)
      set_value(:default_order, value)
    end

    def default_order(*args)
      spawn.default_order!(*args)
    end

    def default_order!(*args)
      if args.blank?
        self.default_order_values = FROZEN_EMPTY_ARRAY
      else
        preprocess_order_args(args)
        self.default_order_values += args
      end
      self
    end

    def where(opts = :chain, *rest)
      if opts == :chain
        WhereChain.new(spawn)
      elsif opts.blank?
        self
      else
        normalize_query_options(opts, rest)
      end
    end

    def uniq_column_values(col, count_col = 'id')
      group!(col)
      order!(col)
      select(col, "COUNT(#{count_col}) as value_count")
    end

    def normalize_query_options(opts, rest)
      query = self

      if opts.is_a?(Hash)
        opts.symbolize_keys!

        opts.keys.each do |k|
          if hash_column = k.to_s.match(/(.+)_hash$/)
            hashed = opts.delete k
            hashed = "\\x#{hashed}" unless hashed =~ /^\\x/
            query = query.spawn.where!("digest(#{hash_column[1]}, 'sha256') = ?", hashed)
          elsif formatter = QueryFormatter::QUERY_FORMATTERS[k]
            opts[k] = opts[k].is_a?(Array) ? opts[k].map!(&formatter) : formatter.call(opts[k])
          elsif k.to_s == "uuid"
            begin
              opts[:id] = opts.delete(k) unless query.klass.columns_hash.has_key?(k.to_s)
            rescue
            end
          end
        end

        return query if opts.blank?
      end

      query.spawn.where!(opts, *rest)
    end

    def exist?
      exists?
    end

    private
      def build_order(arel)
        orders = order_values.uniq
        orders.reject!(&:blank?)

        if orders.empty?
          orders = default_order_values.uniq
          orders.reject!(&:blank?)
          arel.order(*orders) unless orders.empty?
        else
          arel.order(*orders)
        end
      end
  end

  module Calculations
    alias :super_calculate :calculate
    def calculate(*args)
      default_order.super_calculate(*args)
    end
  end

  module CollectionCacheKey
    alias :super_collection_cache_key :collection_cache_key
    def collection_cache_key(collection = all, timestamp_column = :updated_at)
      super_collection_cache_key(collection.default_order, timestamp_column)
    end
  end
end

class ActiveRecord::Relation::Merger
  def merge_multi_values
    if other.reordering_value
      # override any order specified in the original relation
      relation.reorder!(*other.order_values)
    elsif other.order_values.any?
      # merge in order_values from relation
      relation.order!(*other.order_values)
    elsif other.default_order_values.any?
      relation.default_order!(*other.default_order_values)
    end

    extensions = other.extensions - relation.extensions
    relation.extending!(*extensions) if extensions.any?
  end
end

ActiveRecord::Querying.delegate :default_order,
                                :default_order!,
                                :split_batches,
                                :split_batches_values,
                                :uniq_column_values,
                                to: :all
