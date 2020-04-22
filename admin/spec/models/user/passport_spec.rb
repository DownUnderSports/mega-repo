# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User::Passport, type: :model do
  has_valid_factory(:user_passport)

  describe 'Attributes' do
    # run `rails spec:attributes User::Passport` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
