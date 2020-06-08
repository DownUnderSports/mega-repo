require 'rails_helper'

RSpec.describe Team, type: :model do
  has_valid_factory(:team)

  describe 'Attributes' do
    #              name: :text
    #          sport_id: :integer, required
    #          state_id: :integer, required
    # competing_team_id: :integer
    #    departing_date: :date
    #    returning_date: :date
    #          gbr_date: :date
    #         gbr_seats: :integer
    #       default_bus: :text
    # default_wristband: :text
    #     default_hotel: :text
    #        created_at: :datetime, required
    #        updated_at: :datetime, required

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
