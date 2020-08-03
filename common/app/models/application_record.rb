# encoding: utf-8
# frozen_string_literal: true

class ApplicationRecord < BetterRecord::Base
  self.abstract_class = true
  include NullDelegatable
  include Followable

  # == Constants ============================================================
  def self.const_missing(name)
    if name.to_s =~ /^(Public|Year\d+)$/
      self.set_year_const(name)
    else
      super
    end
  end

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  alias_attribute :audits, BetterRecord.audit_relation_name

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.has_one_attached_by_year(name, dependent: :purge_later)
    class_eval <<-CODE, __FILE__, __LINE__ + 1
      def #{name}
        @active_storage_attached_#{name} ||= ActiveStorage::Attached::One.new("#{name}_#{current_year}", self, dependent: #{dependent == :purge_later ? ":purge_later" : "false"})
      end

      def #{name}=(attachable)
        #{name}.attach(attachable)
      end
    CODE

    has_one :"#{name}_#{current_year}_attachment", -> { where(name: "#{name}_#{current_year}") }, class_name: "ActiveStorage::Attachment", as: :record, inverse_of: :record, dependent: false
    has_one :"#{name}_#{current_year}_blob", through: :"#{name}_attachment", class_name: "ActiveStorage::Blob", source: :blob

    alias_attribute :"#{name}_attachment", :"#{name}_#{current_year}_attachment"
    alias_attribute :"#{name}_blob", :"#{name}_#{current_year}_blob"

    scope :"with_attached_#{current_year}_#{name}", -> { includes("#{name}_#{current_year}_attachment": :blob) }
    scope :"with_attached_#{name}", -> { includes("#{name}_#{current_year}_attachment": :blob) }

    if dependent == :purge_later
      after_destroy_commit { public_send(name).purge_later }
    else
      before_destroy { public_send(name).detach }
    end
  end

  def self.has_many_attached_by_year(name, dependent: :purge_later)
    class_eval <<-CODE, __FILE__, __LINE__ + 1
      def #{name}
        @active_storage_attached_#{name} ||= ActiveStorage::Attached::Many.new("#{name}_#{current_year}", self, dependent: #{dependent == :purge_later ? ":purge_later" : "false"})
      end

      def #{name}=(attachables)
        #{name}.attach(attachables)
      end
    CODE

    has_many :"#{name}_#{current_year}_attachments", -> { where(name: name) }, as: :record, class_name: "ActiveStorage::Attachment", inverse_of: :record, dependent: false do
      def purge
        each(&:purge)
        reset
      end

      def purge_later
        each(&:purge_later)
        reset
      end
    end
    has_many :"#{name}_#{current_year}_blobs", through: :"#{name}_attachments", class_name: "ActiveStorage::Blob", source: :blob

    alias_attribute :"#{name}_attachments", :"#{name}_#{current_year}_attachments"
    alias_attribute :"#{name}_blobs", :"#{name}_#{current_year}_blobs"

    scope :"with_attached_#{current_year}_#{name}", -> { includes("#{name}_#{current_year}_attachments": :blob) }
    scope :"with_attached_#{name}", -> { includes("#{name}_#{current_year}_attachments": :blob) }

    if dependent == :purge_later
      after_destroy_commit { public_send(name).purge_later }
    else
      before_destroy { public_send(name).detach }
    end
  end

  def self.set_db_year(year_to_view)
    value = calc_schema_search_path(year_to_view)
    reset_all_schemas unless connection.schema_search_path == value
    connection.schema_search_path = value
  rescue
    set_db_default_year
  end

  def self.set_db_default_year
    value = "#{usable_schema_year},public"
    reset_all_schemas unless connection.schema_search_path == value
    connection.schema_search_path = value
  rescue
    connection.schema_search_path = "public"
  end

  def self.with_year(year_to_view)
    set_db_year(year_to_view)
    yield
  ensure
    set_db_default_year
  end

  def self.calc_schema_search_path(year_to_view)
    "#{get_schema_name_from_year(year_to_view)},public"
  end

  def self.get_schema_name_from_year(year_to_view)
    year_to_view = year_to_view.to_s.downcase.gsub(/[^0-9]/, '')

    (year_to_view =~ /\d+/) ? "year_#{year_to_view}" : "public"
  end

  def self.current_year
    value = "#{ENV['CURRENT_YEAR'].to_s}".strip
    value.empty? ? nil : value
  end

  def self.current_schema_year
    current_year ? "year_#{current_year}" : "public"
  end

  def self.usable_schema_year
    return 'public' unless current_year
    @@usable_schema_year ||= begin

      result = ActiveRecord::Base.connection.execute <<-SQL
        SELECT EXISTS (
          SELECT 1
          FROM pg_namespace
          WHERE nspname = '#{current_schema_year}'
        )
      SQL

      result.first['exists'] ? current_schema_year : 'public'
    rescue Exception
      'public'
    end
  end

  def self.reset_cached_usable_schema_year
    @@usable_schema_year = nil
  end

  def self.active_schema_year
    connection.schema_search_path.split(',').first.strip.sub('year_', '').to_i
  rescue
    0
  end

  def self.active_year
    @@active_year ||= (Date.today.year + ((Date.today.month < 9) ? 0 : 1))
  end

  def self.is_active_year?
    active_schema_year >= active_year
  end

  def self.is_public_schema?
    connection.schema_search_path.split(',').first == 'public'
  end

  def self.[](key)
    get key
  end

  def self.indifferent_reflections
    reflections.with_indifferent_access
  end

  def self.model
    self.all
  end

  def self.attribute_types_hash
    return @attribute_types_hash if @attribute_types_hash.present?
    @attribute_types_hash = {}
    attribute_types.each do |k,v|
      @attribute_types_hash[k] = v.is_a?(BetterRecord::MoneyInteger::Type) ? 'money' : v.type.to_s
    end
    @attribute_types_hash.freeze
  end

  def self.attribute_types_arr(as_hashes = false)
    if as_hashes
      self.attribute_types_hash.to_a.map do |k, v|
        {
          'name' => k,
          'type' => v
        }
      end
    else
      self.attribute_types_hash.to_a
    end
  end

  def self.get_sha256_digest(str, looped = false)
    return nil unless str.present?
    begin
      begin
        get_sha256_digest_statement
      rescue PG::DuplicatePstatement
      end
      self.connection.raw_connection.exec_prepared('get_sha256_digest', [ str ]).first['string_hash']&.sub(/^\\x/, '')
    rescue
      @get_sha256_digest_statement = nil
      get_sha256_digest(str, true) unless looped
    end
  end

  def self.get_sha256_digest_statement
    @get_sha256_digest_statement ||= self.connection.raw_connection.prepare('get_sha256_digest', "SELECT digest($1, 'sha256') as string_hash;")
  end

  def self.verified_address(old_id, new_id)
    where(address_id: old_id).update(address_id: new_id)
  end

  def self.execute_model_sql_file(filename)
    filename = filename.to_s.gsub('.?./', '/') while filename =~ /\.+\//
    execute_sql_file([self.name.underscore, ].join('/'))
  end

  def self.execute_sql_file(filename)
    filename = "#{filename}.sql".sub(/(\.sql)+/, '.sql')

    file = Rails.root.join('app', 'queries', filename)

    file = Rails.root.join('vendor', 'common', 'app', 'queries', filename) unless File.exist?(file)

    connection.execute(File.read(file))
  end

  def self.a_t
    self.arel_table
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def dus_id
    self[:dus_id].to_s.scan(/.{1,3}/).join('-').presence
  end

  def model
    self.class.where(self.class.primary_key => self.__send__(self.class.primary_key))
  end

  def present?
    true
  end

  def blank?
    false
  end

  def transfer_to_db_year(year_to_use)
    v = nil
    transaction do
      pk_to_use = self.class.primary_key || :id

      self.class.connection.execute <<-SQL
        WITH deleted AS (
          DELETE FROM ONLY "#{self.class.schema_qualified[:schema_name]}"."#{self.class.schema_qualified[:table_name]}"
          WHERE #{pk_to_use} = '#{self.__send__(pk_to_use)}'
          RETURNING *
        )
        INSERT INTO "#{get_schema_name_from_year(year_to_use)}"."#{self.class.schema_qualified[:table_name]}"
        SELECT * FROM deleted;
      SQL

      with_year(year_to_use) { v = self.class.find(self.__send__(pk_to_use)) }
    end
    v
  end

  def check_active_year
    unless is_active_year? || is_public_schema?
      errors.add(:base, "CANNOT PERFORM ACTION IN PREVIOUS YEARS")
      throw :abort
    end

    true
  end
end
