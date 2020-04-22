require 'rails_helper'

RSpec.describe Sport::Info, type: :model do
  has_valid_factory(:sport_info)

  describe 'Attributes' do
    #            sport_id: :integer, required
    #               title: :text, required
    #          tournament: :text, required
    #          first_year: :integer, required
    #     departing_dates: :text, required
    #          team_count: :text, required
    #           team_size: :text, required
    #         description: :text, required
    # bullet_points_array: :text, required, array, default: []
    #    background_image: :text
    #          additional: :text
    #          created_at: :datetime, required
    #          updated_at: :datetime, required

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
