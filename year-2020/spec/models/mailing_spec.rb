# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mailing, type: :model do
  has_valid_factory(:mailing)

  describe 'Attributes' do
    #    user_id: :integer
    #   category: :text
    #       sent: :date
    #    printed: :boolean, required
    #    is_home: :boolean, required
    # is_foreign: :boolean, required
    #       auto: :boolean, required
    #     failed: :boolean, required
    #     street: :text, required
    #   street_2: :text
    #   street_3: :text
    #       city: :text, required
    #      state: :text, required
    #        zip: :text, required
    #    country: :text
    # created_at: :datetime, required
    # updated_at: :datetime, required

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
