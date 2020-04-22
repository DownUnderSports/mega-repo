# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment::Remittance, type: :model do
  has_valid_factory(:payment_remittance)

  describe 'Attributes' do
    # run `rails spec:attributes Payment::Remittance` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
