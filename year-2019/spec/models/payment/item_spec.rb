# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment::Item, type: :model do
  has_valid_factory(:payment_item)

  describe 'Attributes' do
    # run `rails spec:attributes Payment::Item` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
