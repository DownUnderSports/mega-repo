require 'rails_helper'

RSpec.describe User, type: :model do
  has_valid_factory(:user)

  describe 'Attributes' do
    #            dus_id: :text, required
    #     category_type: :string
    #       category_id: :integer
    #             email: :text
    #          password: :text
    #   register_secret: :text
    #       certificate: :text
    #             first: :text
    #            middle: :text
    #              last: :text
    #            suffix: :text
    # print_first_names: :text
    # print_other_names: :text
    #         nick_name: :text
    #         keep_name: :boolean, required
    #        address_id: :integer
    #       interest_id: :integer
    #         extension: :text
    #             phone: :text
    #          can_text: :boolean, required
    #            gender: :text, required
    #        shirt_size: :text
    #        created_at: :datetime, required
    #        updated_at: :datetime, required

    [ :first, :last ].each do |nm|
      required_column(:user, nm) do
        it "is must be at least 2 characters" do
          record.__send__("#{nm}=", 'a')
          expect(record.valid?).to be false
          expect(record.errors[nm.to_sym]).to include("is too short (minimum is 2 characters)")

          record.__send__("#{nm}=", 'ab')
          expect(record.valid?).to be true
          expect(record.save).to be true
        end
      end
    end

    [ :middle, :suffix ].each do |nm|
      optional_column(:user, nm) do
        it 'cooerces blank values to nil' do
          record[nm] = ''
          expect(record.__send__(nm)).to eq nil
        end
      end
    end

    required_column(:user, :dus_id) do
      it "is exactly 6 characters"
    end
  end

  describe 'Associations' do
    pending "add some examples to (or delete) #{__FILE__} Attributes"
  end
end
