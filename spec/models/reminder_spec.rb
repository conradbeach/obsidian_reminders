require "rails_helper"

RSpec.describe Reminder do
  # A Monday evening in Mountain time.
  let(:now) { Time.zone.parse("2026-10-19 18:00") }

  before { travel_to now }

  describe ".sync" do
    def vault_with(*reminders)
      instance_double(Vault, reminders:)
    end

    let(:dentist) { { note_path: "Errands.md", line: "Call the dentist (@tomorrow 9am)", directive: "tomorrow 9am" } }

    context "when the vault has a new directive" do
      it "creates a reminder scheduled relative to now" do
        described_class.sync(vault_with(dentist))

        expect(described_class.sole).to have_attributes(**dentist, remind_at: Time.zone.parse("2026-10-20 09:00"))
      end
    end

    context "when the directive's time can't be parsed" do
      it "creates an unscheduled reminder" do
        described_class.sync(vault_with(dentist.merge(directive: "whenever")))

        expect(described_class.sole.remind_at).to be_nil
      end
    end

    context "when a reminder's directive is still in the vault" do
      it "keeps the reminder as it was, without rescheduling it" do
        reminder = create(:reminder, **dentist, remind_at: 2.hours.ago, notified_at: 1.hour.ago)

        described_class.sync(vault_with(dentist))

        expect(described_class.sole)
          .to have_attributes(id: reminder.id, remind_at: 2.hours.ago, notified_at: 1.hour.ago)
      end
    end

    context "when a reminder's directive is no longer in the vault" do
      it "deletes the reminder" do
        create(:reminder, line: "Pick up dry cleaning (@friday)", directive: "friday")

        described_class.sync(vault_with(dentist))

        expect(described_class.pluck(:line)).to eq([dentist[:line]])
      end
    end
  end

  describe ".notify_due" do
    before { allow(WebPush).to receive(:payload_send) }

    context "when a reminder's time has come" do
      it "notifies every device and marks the reminder notified" do
        create(:push_subscription)
        reminder = create(:reminder, note_path: "Errands.md", line: "Call the dentist (@6pm)", remind_at: 1.minute.ago)

        described_class.notify_due

        message = { title: "Call the dentist", options: { body: "Errands", data: { path: "/" } } }.to_json
        expect(WebPush).to have_received(:payload_send).with(hash_including(message:))
        expect(reminder.reload.notified_at).to eq(now)
      end
    end

    context "when no device accepts the notification" do
      it "leaves the reminder unsent to retry" do
        reminder = create(:reminder, remind_at: 1.minute.ago)

        described_class.notify_due

        expect(reminder.reload.notified_at).to be_nil
      end
    end

    context "when a reminder is in the future, already sent, or more than an hour past" do
      it "doesn't notify about it" do
        create(:push_subscription)
        create(:reminder, remind_at: 1.minute.from_now)
        create(:reminder, remind_at: 1.minute.ago, notified_at: 1.minute.ago)
        create(:reminder, remind_at: 61.minutes.ago)

        described_class.notify_due

        expect(WebPush).to_not have_received(:payload_send)
      end
    end
  end

  describe "#text" do
    context "when the line is a task with a directive" do
      it "returns the task without its checkbox or directive" do
        reminder = build(:reminder, line: "- [ ] Call the dentist (@tomorrow 9am) about Tuesday")

        expect(reminder.text).to eq("Call the dentist about Tuesday")
      end
    end

    context "when the line is a numbered list item" do
      it "returns the item without its number" do
        expect(build(:reminder, line: "2. Water the plants (@friday)").text).to eq("Water the plants")
      end
    end

    context "when the line is only a directive" do
      it "returns the note's name" do
        expect(build(:reminder, note_path: "Home/Car registration.md", line: "(@Nov 1)").text)
          .to eq("Car registration")
      end
    end
  end

  describe "#obsidian_url" do
    it "links to the note in the vault" do
      reminder = build(:reminder, note_path: "Home/Car registration.md")

      expect(reminder.obsidian_url).to eq("obsidian://open?vault=Vault&file=Home%2FCar%20registration.md")
    end
  end
end
