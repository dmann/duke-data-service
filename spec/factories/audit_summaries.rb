FactoryBot.define do
  factory :audit_summary do
    trait :with_auditable do
      association :auditable, factory: :software_agent
    end
  end
end
