# encoding: utf-8
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatRoom::Message, type: :model do
  has_valid_factory(:chat_room_message)

  describe 'Attributes' do
    # run `rails spec:attributes ChatRoom::Message` to replace this line

    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
