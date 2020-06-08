# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShirtOrder::Item, type: :model do
  has_valid_factory(:shirt_order_item)

  describe 'Attributes' do
    # run `rails spec:attributes ShirtOrder::Item` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
