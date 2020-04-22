# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Payment::Term, type: :model do
  has_valid_factory(:payment_terms)

  describe 'Attributes' do
    # run `rails spec:attributes Payment::Terms` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
