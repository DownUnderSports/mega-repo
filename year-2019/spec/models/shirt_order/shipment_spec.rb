# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShirtOrder::Shipment, type: :model do
  has_valid_factory(:shirt_order_shipment)

  describe 'Attributes' do
    # run `rails spec:attributes ShirtOrder::Shipment` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
