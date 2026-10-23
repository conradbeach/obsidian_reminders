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

    context "when the vault has a new directive that repeats until a relative date" do
      it "stores the date it ends on, read once, relative to now" do
        described_class.sync(vault_with(dentist.merge(line: "Floss (@every day until friday)",
          directive: "every day until friday")))

        expect(described_class.sole).to have_attributes(remind_at: Time.zone.parse("2026-10-20 09:00"),
          ends_on: Date.new(2026, 10, 23))
      end
    end

    context "when the directive's time can't be parsed" do
      it "creates an unscheduled reminder" do
        described_class.sync(vault_with(dentist.merge(directive: "whenever")))

        expect(described_class.sole.remind_at).to be_nil
      end
    end

    context "when an unscheduled reminder's directive can now be parsed" do
      it "schedules it relative to now" do
        reminder = create(:reminder, **dentist, remind_at: nil)

        described_class.sync(vault_with(dentist))

        expect(described_class.sole).to have_attributes(id: reminder.id, remind_at: Time.zone.parse("2026-10-20 09:00"))
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

    context "when a reminder's line is now under a different heading and has new notes" do
      it "updates the heading and notes without rescheduling the reminder" do
        reminder = create(:reminder, **dentist, remind_at: 2.hours.ago, heading: "Errands", notes: nil)

        described_class.sync(vault_with(dentist.merge(heading: "This week", notes: "Ask about the crown")))

        expect(described_class.sole).to have_attributes(id: reminder.id, remind_at: 2.hours.ago, heading: "This week",
          notes: "Ask about the crown")
      end
    end

    context "when a reminder's directive is no longer in the vault" do
      it "hides the reminder, then deletes it once it's been missing for five minutes" do
        reminder = create(:reminder, note_path: "Tabitha/Errands.md", line: "Pick up dry cleaning (@friday)")
        user = create(:user, note_folders: ["Tabitha"])

        described_class.sync(vault_with)
        expect(user.reminders).to be_empty
        expect(described_class).to exist(reminder.id)

        travel 5.minutes
        described_class.sync(vault_with)
        expect(described_class).to_not exist(reminder.id)
      end
    end

    context "when a missing reminder comes back within five minutes" do
      it "keeps its original time and sent state" do
        reminder = create(:reminder, **dentist, remind_at: 2.hours.ago, notified_at: 1.hour.ago)

        described_class.sync(vault_with)
        travel 4.minutes
        described_class.sync(vault_with(dentist))

        expect(reminder.reload).to have_attributes(remind_at: now - 2.hours, notified_at: now - 1.hour,
          missing_since: nil)
      end
    end
  end

  describe ".notify_due" do
    before { allow(WebPush).to receive(:payload_send) }

    context "when a reminder's time has come" do
      it "notifies the devices of users whose folders contain the note and marks the reminder notified" do
        tabitha = create(:user, note_folders: ["Tabitha"])
        create(:push_subscription, user: tabitha, endpoint: "https://web.push.apple.com/tabitha")
        create(:push_subscription, user: create(:user, note_folders: ["Conrad"]))
        reminder = create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@6pm)",
          remind_at: 1.minute.ago)

        described_class.notify_due

        message = { title: "Call the dentist", options: { data: { path: "/" } } }.to_json
        expect(WebPush).to have_received(:payload_send).once
          .with(hash_including(endpoint: "https://web.push.apple.com/tabitha", message:))
        expect(reminder.reload.notified_at).to eq(now)
      end
    end

    context "when no recipient's device accepts the notification" do
      it "leaves the reminder unsent to retry" do
        create(:user, note_folders: ["Tabitha"])
        reminder = create(:reminder, note_path: "Tabitha/Errands.md", remind_at: 1.minute.ago)

        described_class.notify_due

        expect(reminder.reload.notified_at).to be_nil
      end
    end

    context "when the note isn't in anyone's folders" do
      it "doesn't notify about it" do
        create(:push_subscription, user: create(:user, note_folders: ["Tabitha"]))
        create(:reminder, note_path: "Archive/Errands.md", remind_at: 1.minute.ago)

        described_class.notify_due

        expect(WebPush).to_not have_received(:payload_send)
      end
    end

    context "when a reminder is in the future, already sent, or more than an hour past" do
      it "doesn't notify about it" do
        create(:push_subscription, user: create(:user, note_folders: ["Tabitha"]))
        create(:reminder, note_path: "Tabitha/Errands.md", remind_at: 1.minute.from_now)
        create(:reminder, note_path: "Tabitha/Errands.md", remind_at: 1.minute.ago, notified_at: 1.minute.ago)
        create(:reminder, note_path: "Tabitha/Errands.md", remind_at: 61.minutes.ago)

        described_class.notify_due

        expect(WebPush).to_not have_received(:payload_send)
      end
    end
  end

  describe "#complete" do
    it "hides the reminder at once and checks it off in its note in the background" do
      user = create(:user, note_folders: ["Tabitha"])
      reminder = create(:reminder, note_path: "Tabitha/Errands.md")

      expect { reminder.complete }.to have_enqueued_job(CheckOffReminderJob).with(reminder)
      expect(user.reminders).to be_empty
    end

    context "when the reminder repeats" do
      it "moves it to its next occurrence, to be notified about again, without checking it off" do
        reminder = create(:reminder, directive: "every monday and thursday at 7pm",
          line: "Run (@every monday and thursday at 7pm)",
          remind_at: Time.zone.parse("2026-10-19 19:00"), notified_at: Time.zone.parse("2026-10-19 19:00"))

        expect { reminder.complete }.to_not have_enqueued_job(CheckOffReminderJob)
        expect(reminder.reload).to have_attributes(
          remind_at: Time.zone.parse("2026-10-22 19:00"), notified_at: nil, completed_at: nil,
        )
      end
    end

    # Marks each occurrence done when it's due until the reminder is finished, returning when each was due.
    def complete_each_occurrence(reminder)
      times = []
      until reminder.completed_at
        times << reminder.remind_at
        travel_to(reminder.remind_at) { reminder.complete }
      end
      times
    end

    # Read on Monday, October 19, 2026, at 6pm.
    def scheduled_reminder(directive)
      described_class.new(note_path: "Errands.md", line: "Run (@#{directive})", directive:).tap(&:schedule)
        .tap(&:save!)
    end

    def self.finishes(rows)
      rows.each do |directive, dates|
        it "repeats “#{directive}” on #{dates.join(', ')}, then checks it off" do
          reminder = scheduled_reminder(directive)

          expect { expect(complete_each_occurrence(reminder)).to eq(dates.map { Time.zone.parse(it) }) }
            .to have_enqueued_job(CheckOffReminderJob).with(reminder).once
        end
      end
    end

    context "when a repeating reminder has an end" do
      finishes [
        ["every day until Tuesday", ["2026-10-20 09:00"]],
        ["every day until Friday", ["2026-10-20 09:00", "2026-10-21 09:00", "2026-10-22 09:00", "2026-10-23 09:00"]],
        ["every day from Wednesday to Friday", ["2026-10-21 09:00", "2026-10-22 09:00", "2026-10-23 09:00"]],
        ["every day until friday at 8pm", ["2026-10-19 20:00", "2026-10-20 20:00", "2026-10-21 20:00",
                                           "2026-10-22 20:00", "2026-10-23 20:00"]],
        ["every other day from Monday to Friday", ["2026-10-26 09:00", "2026-10-28 09:00", "2026-10-30 09:00"]],
        ["every day for 1 week", ["2026-10-20 09:00", "2026-10-21 09:00", "2026-10-22 09:00", "2026-10-23 09:00",
                                  "2026-10-24 09:00", "2026-10-25 09:00", "2026-10-26 09:00"]],
        ["every week for 2 months", ["2026-10-20 09:00", "2026-10-27 09:00", "2026-11-03 09:00", "2026-11-10 09:00",
                                     "2026-11-17 09:00", "2026-11-24 09:00", "2026-12-01 09:00", "2026-12-08 09:00",
                                     "2026-12-15 09:00"]],
        ["every 3 days for 3 weeks", ["2026-10-20 09:00", "2026-10-23 09:00", "2026-10-26 09:00", "2026-10-29 09:00",
                                      "2026-11-01 09:00", "2026-11-04 09:00", "2026-11-07 09:00"]],
        ["every monday and thursday from oct 26 to nov 5 at 7pm",
         ["2026-10-26 19:00", "2026-10-29 19:00", "2026-11-02 19:00", "2026-11-05 19:00"]],
      ]

      it "checks it off when it's done after its last day" do
        reminder = scheduled_reminder("every day until friday")
        reminder.update!(remind_at: Time.zone.parse("2026-10-22 09:00"))

        travel_to(Time.zone.parse("2026-10-24 10:00")) { reminder.complete }

        expect(reminder.reload.completed_at).to be_present
      end
    end

    it "is never notified about" do
      create(:push_subscription, user: create(:user, note_folders: ["Tabitha"]))
      allow(WebPush).to receive(:payload_send)
      create(:reminder, note_path: "Tabitha/Errands.md", remind_at: 1.minute.ago, completed_at: 2.minutes.ago)

      described_class.notify_due

      expect(WebPush).to_not have_received(:payload_send)
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
    context "when the reminder is under a heading" do
      it "links to the heading in the note" do
        reminder = build(:reminder, note_path: "Home/Car registration.md", heading: "This year")

        expect(reminder.obsidian_url).to eq("obsidian://open?vault=Vault&file=Home%2FCar%20registration%23This%20year")
      end
    end

    context "when the reminder isn't under a heading" do
      it "links to the note" do
        reminder = build(:reminder, note_path: "Home/Car registration.md", heading: nil)

        expect(reminder.obsidian_url).to eq("obsidian://open?vault=Vault&file=Home%2FCar%20registration")
      end
    end
  end
end
