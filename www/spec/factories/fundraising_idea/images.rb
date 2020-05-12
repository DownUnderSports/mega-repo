FactoryBot.define do
  factory :fundraising_idea_image, class: 'FundraisingIdea::Image' do
    alt { "MyText" }
    display_order { 1 }
  end
end
