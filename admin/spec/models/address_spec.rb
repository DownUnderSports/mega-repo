require 'rails_helper'

RSpec.describe Address, type: :model do
  has_valid_factory(:pre_verified_address)

  describe 'Attributes' do
    # student_list_id: :integer
    #      is_foreign: :boolean, required
    #          street: :text, required
    #        street_2: :text
    #        street_3: :text
    #            city: :text, required
    #        state_id: :integer
    #        province: :text
    #             zip: :text, required
    #         country: :text
    #       tz_offset: :integer
    #             dst: :boolean, required
    #        rejected: :boolean, required
    #        verified: :boolean, required
    #      created_at: :datetime, required
    #      updated_at: :datetime, required

    boolean_column(:pre_verified_address, :is_foreign)
    required_column(:pre_verified_address, :street)
    optional_column(:pre_verified_address, :street_2)
    optional_column(:pre_verified_address, :street_3)
    required_column(:pre_verified_address, :city)
    optional_column(:pre_verified_address, :province)
    required_column(:pre_verified_address, :zip)
    optional_column(:pre_verified_address, :country)
    optional_column(:pre_verified_address, :tz_offset)
    boolean_column(:pre_verified_address, :dst)
    boolean_column(:pre_verified_address, :rejected)
    boolean_column(:pre_verified_address, :verified)

  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
