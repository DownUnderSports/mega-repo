# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User::Message, type: :model do
  has_valid_factory(:user_message)

  describe 'Attributes' do
    #    user_id: :integer, required
    #   staff_id: :integer, required
    #       type: :text, required
    #   category: :text, required
    #    message: :text, required
    #   reviewed: :boolean, required
    # created_at: :datetime, required
    # updated_at: :datetime, required

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
