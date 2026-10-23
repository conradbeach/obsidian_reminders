require "rails_helper"

RSpec.describe IdentifyReminderJob do
  around do |example|
    Dir.mktmpdir do |dir|
      original_path = Rails.configuration.x.vault_path
      Rails.configuration.x.vault_path = dir
      example.run
    ensure
      Rails.configuration.x.vault_path = original_path
    end
  end

  let(:note) { Pathname(Rails.configuration.x.vault_path).join("Errands.md") }

  it "ends the reminder's line with a new block ID, which the next sync takes on" do
    note.write("- [ ] Call the dentist (@friday)\n")
    Reminder.sync(Vault.synced)

    described_class.perform_now(Reminder.sole)
    Reminder.sync(Vault.synced)

    block_id = Reminder.sole.block_id
    expect(block_id).to match(/\A[A-Z0-9]{4}\z/)
    expect(note.read).to eq("- [ ] Call the dentist (@friday) ^#{block_id}\n")
  end

  context "when the reminder already has a block ID" do
    it "leaves the note alone" do
      note.write("- [ ] Call the dentist (@friday) ^K3P9\n")
      reminder = create(:reminder, note_path: "Errands.md", line: "- [ ] Call the dentist (@friday) ^K3P9",
        block_id: "K3P9")

      described_class.perform_now(reminder)

      expect(note.read).to eq("- [ ] Call the dentist (@friday) ^K3P9\n")
    end
  end
end
