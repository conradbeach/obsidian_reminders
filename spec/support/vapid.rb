# Keeps the real VAPID keys, which sign push notifications, out of failing tests' output.
RSpec.configure do |config|
  config.before do
    allow(Rails.application.credentials).to receive(:vapid)
      .and_return({ subject: "mailto:test@example.com", public_key: "test-public", private_key: "test-private" })
  end
end
