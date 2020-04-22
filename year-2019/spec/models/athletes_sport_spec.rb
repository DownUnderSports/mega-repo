require 'rails_helper'

RSpec.describe AthletesSport, type: :model do
  has_valid_factory(:athletes_sport)

  describe 'Attributes' do
    #      athlete_id: :integer
    #        sport_id: :integer
    #            rank: :integer
    #           stats: :text
    #         invited: :boolean, required
    #    invited_date: :date
    #          height: :text
    #          weight: :text
    #        handicap: :text
    # positions_array: :text, required
    #      created_at: :datetime, required
    #      updated_at: :datetime, required

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
