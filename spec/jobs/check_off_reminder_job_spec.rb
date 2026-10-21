require "rails_helper"

RSpec.describe CheckOffReminderJob do
  around do |example|
    Dir.mktmpdir do |dir|
      original_path = Rails.configuration.x.vault_path
      Rails.configuration.x.vault_path = dir
      example.run
    ensure
      Rails.configuration.x.vault_path = original_path
    end
  end

  it "checks off the reminder's line in its note" do
    File.write("#{Rails.configuration.x.vault_path}/Errands.md", "- [ ] Call the dentist (@friday)\n")
    reminder = create(:reminder, note_path: "Errands.md", line: "- [ ] Call the dentist (@friday)")

    described_class.perform_now(reminder)

    expect(File.read("#{Rails.configuration.x.vault_path}/Errands.md")).to eq("- [x] Call the dentist (@friday)\n")
  end
end
