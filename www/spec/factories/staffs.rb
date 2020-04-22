FactoryBot.define do
  factory :staff do
    certificate { "MyText" }
    admin { false }
    finances { false }
    australia { false }
    recaps { false }
    uniforms { false }
    flights { false }
    remittances { false }
  end
end
