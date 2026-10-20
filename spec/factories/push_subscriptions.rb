FactoryBot.define do
  factory :push_subscription do
    user
    sequence(:endpoint) { |n| "https://fcm.googleapis.com/fcm/send/#{n}" }
    p256dh_key { "p256dh-key" }
    auth_key { "auth-key" }
  end
end
