require "rails_helper"

RSpec.describe CheckRemindersJob do
  around do |example|
    Dir.mktmpdir do |dir|
      original_path = Rails.configuration.x.vault_path
      Rails.configuration.x.vault_path = dir
      example.run
    ensure
      Rails.configuration.x.vault_path = original_path
    end
  end

  it "notifies about a reminder once its time comes" do
    travel_to Time.zone.parse("2026-10-19 18:00")
    create(:push_subscription)
    allow(WebPush).to receive(:payload_send)
    Pathname(Rails.configuration.x.vault_path).join("Errands.md").write("- [ ] Call the dentist (@in 5 minutes)")

    described_class.perform_now
    expect(WebPush).to_not have_received(:payload_send)

    travel 5.minutes
    described_class.perform_now
    expect(WebPush).to have_received(:payload_send).once
  end
end
