FactoryBot.define do
  factory :chat_room_message, class: 'ChatRoom::Message' do
    chat_room { nil }
    user { nil }
    message { "MyText" }
  end
end
