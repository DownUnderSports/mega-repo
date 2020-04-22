# encoding: utf-8
# frozen_string_literal: true

class StudentList < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.student_lists"

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :addresses, inverse_of: :student_list
  has_many :athletes,
    foreign_key: :student_list_date,
    primary_key: :sent,
    inverse_of: :student_list

  # == Validations ==========================================================
  validates :sent, presence: true, uniqueness: true

  # == Scopes ===============================================================
  scope :incomplete, -> { where(received: nil) }

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.csv_headers
    %w( athlete_id team_name grad first last school_city school_state school_zip sent )
  end

  def self.csv_rows(params, &block)
    student_list = find_by(sent: params[:date]) || self.new(sent: params[:date])
    if student_list.save
      Athlete.
      joins(school: [address: :state]).
      joins(
        <<-SQL
          INNER JOIN teams ON
          (
            (teams.state_id = addresses.state_id)
            AND
            (teams.sport_id = athletes.sport_id)
          )
        SQL
      ).
      where(student_list_date: student_list.sent).
      select("athletes.id, teams.name, athletes.grad, athletes.full_name, addresses.city, states.abbr as state_abbr, addresses.zip, athletes.student_list_date").
      find_each(batch_size: 100) do |record|
        name_split = record.full_name.split(' ')
        yield [
          record.id,
          record.name,
          record.grad,
          name_split[0],
          name_split[1..-1],
          record.city,
          record.state_abbr,
          record.zip,
          record.student_list_date.to_s
        ]
      end
    else
      []
    end

  end

  def self.parse_csv(path, list_id, original_filename)
    list = find_by(id: list_id)
    list.received = Date.today
    list.save
    p path
    restricted_id = Interest::Restricted.id
    errors = []
    Address.set_to_batch

    CSV.foreach(path, headers: true, header_converters: -> h { h.downcase.underscore.gsub(/(\s|\=)/,'_') } ) do |row|
      begin
        athlete = Athlete.find_by(id: (row['athlete_id'] || row['your_contact_id']))
        if athlete
          unless row["restricted_name_endorsement_line_if_applicable"].blank?
            athlete.update(interest_id: restricted_id)
            next
          end
          p values = {
            addresses_attributes: {
              '0' => {
                street: row['street'],
                street_2: (row['care_of'].blank? ? nil : row['care_of']),
                state_id: State.find_by_value(row['st'] || row['state']).id,
                city: row['city'],
                zip: row['zip'],
                student_list_id: list.id
              }
            }
          }
          values[:first] = row['first_name'] if row['your_first_name'] != row['first_name']
          values[:last] = row['last_name'] if row['your_last_name'] != row['last_name']
          unless row['gender_m_male_f_female'].blank? || row['gender_m_male_f_female'] == 'U'
            values[:gender] = row['gender_m_male_f_female'].upcase
          end
          athlete.update_columns(grad: (2000 + row['class_year'].to_i)) unless row['class_year'].blank?
          athlete.user.update(values)
        end
      rescue
        puts $!.message
        puts $!.backtrace.first(10)
        errors << row.to_h.merge({error: $!.message, error_line: $!.backtrace.first})
      end
    end

    unless errors.blank?
      require 'tempfile'
      temp = Tempfile.new
      CSV.open(temp, 'w') do |csv|
        csv << errors.first.keys
        errors.each {|row| csv << row.values}
      end
      retries = 0
      begin
        StaffMailer.upload_errors('Student List', Staff.find_by(first: 'Kathy').id, temp, original_filename).deliver
      rescue
        sleep retries += 1
        retry if retries < 20
      end
    end

    Address.set_to_normal
    Address.process_batches
    File.delete(path)
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

  set_audit_methods!
end
