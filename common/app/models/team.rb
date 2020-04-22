# encoding: utf-8
# frozen_string_literal: true

class Team < ApplicationRecord
  # == Constants ============================================================
  TRACK_DATES = {
    0 =>
      %w[
        ABQ AMA ANC BIL BIS BOI DEN DFW ELP FAI FAR FAT FSD GEG GTF HNL IAH
        ICT LAS LAX LBB MAF MFE MFR MSO OKC OMA PDX PHX RAP RNO SAT SEA SFO
        SLC SMF TUL TUS
      ],
    1 =>
      %w[
        ATL BDL BHM BNA BOS BTR BWI CHS CLE CLT CMH CRW CVG DCA DSM DTW EWR
        GPT GRB GRR HSV IAD IND JAN JAX JFK LEX LGA LIT MCI MCO MDT MEM MIA
        MKE MQT MSP MSY ORD ORF PHL PIT RDU RIC ROC RSW SAV SDF STL SYR TLH
        TVC
      ]
  }.map do |k, v|
    v.map {|a| [a, k] }
  end.flatten(1).to_h.freeze

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.teams"

  # == Extensions ===========================================================
  include FindByTeamName

  def serializable_hash(*)
    super.tap do |h|
      h['state_abbr'] = self.state.abbr
      h['sport_abbr'] = self.sport.abbr
      h['sport_abbr_gender'] = self.sport.abbr_gender
    end
  end

  # == Relationships ========================================================
  belongs_to :sport, inverse_of: :teams
  belongs_to :state, inverse_of: :teams
  belongs_to :competing_team, optional: true, inverse_of: :teams

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  before_save :check_active_year
  before_destroy :check_active_year

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def invite_rule
    Invite::Rule.find_by(sport_id: sport_id, state_id: state_id)
  end

  def track_number
    ((state.abbr =~ /HI/) || (state.conference =~ /(Central|Mountain)/)) ? 1 : 2
  end

  def track_date
    @track_date ||= Date.new(track_number == 1 ? '2018-07-06' : '2018-07-07')
  end

  def poster
    @poster ||= Sport::DRIVE_POSTERS[:"#{sport.abbr.downcase}"]
  end

  def title
    "#{state.full} #{sport.full_gender}"
  end

  def to_s
    to_str
  end

  def to_str
    title
  end

  def departing_dates
    self.sport&.info&.departing_dates_only
  end

  def returning_dates
    self.sport&.info&.returning_dates_only
  end
end
