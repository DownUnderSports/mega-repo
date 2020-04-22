FactoryBot.define do
  factory :user do
    category { nil }
    first { "MyText" }
    last { "MyText" }
    address { nil }
    interest { nil }
    can_text { false }
    gender { 'M' }
    shirt_size { nil }
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
  end
end
