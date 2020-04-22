# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler/debit'

class Traveler < ApplicationRecord
  class Debit < ApplicationRecord
    # == Constants ============================================================
    AIRFARE = {
      574_00 => \
        %w[
          ANC ATL BDL BHM BIL BIS BNA BOS BTR BWI CHS CLE CLT CMH CRW CVG DCA
          DSM DTW EUG EWR FAI FAR FSD GPT GRB GRR GTF HSV IAD IND JAN JAX JFK
          LEX LGA LIT MCO MDT MEM MIA MKE MOB MQT MSO MSP MSY MYR OKC OMA ORD
          ORF PHL PIT RAP RDU RIC ROC RSW SAV SDF SYR TLH TUL TVC
        ],
      474_00 => \
        %w[ AMA BOI DFW ELP GEG HNL IAH ICT LBB MAF MCI MFE SAT STL ],
      374_00 => \
        %w[ ABQ DEN MFR PHX SEA SLC TUS YVR YYC ],
      299_00 => \
        %w[ FAT RNO SMF ],
      229_00 => \
        %w[ LAS PDX ],
      124_00 => \
        %w[ SFO ],
      0 => \
        %w[ LAX YYZ ]
    }.map do |k, v|
      v.map {|a| [a, k] }
    end.flatten(1).to_h.freeze
  end
end
