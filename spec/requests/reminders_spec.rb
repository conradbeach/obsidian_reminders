require "rails_helper"

RSpec.describe "Reminders" do
  describe "GET /" do
    it "lists upcoming reminders grouped by day, soonest first" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, line: "Renew passport (@Dec 1)", remind_at: Time.zone.parse("2026-12-01 08:00"))
      create(:reminder, line: "Call the dentist (@tomorrow 9am)", remind_at: Time.zone.parse("2026-10-20 09:00"))

      get root_path

      upcoming = response.parsed_body.css("#upcoming-reminders h2, #upcoming-reminders li p.font-medium").map(&:text)
      expect(upcoming).to eq(["Tomorrow", "Call the dentist", "Tue, Dec 1", "Renew passport"])
    end

    it "leaves out overdue reminders and other users' reminders" do
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Pay rent (@Oct 1)", remind_at: 2.days.ago)
      create(:reminder, note_path: "Conrad/Errands.md", line: "Change the oil (@tomorrow)", remind_at: 1.day.from_now)

      get root_path

      expect(response.parsed_body.css("#upcoming-reminders li")).to be_empty
    end

    it "keeps past reminders on their day, dimmed, until they're overdue" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"], overdue_after_hours: 24)
      create(:reminder, line: "Call the dentist (@9am)", remind_at: Time.zone.parse("2026-10-19 09:00"))
      create(:reminder, line: "Water the plants (@yesterday 8pm)", remind_at: Time.zone.parse("2026-10-18 20:00"))

      get root_path

      upcoming = response.parsed_body.css("#upcoming-reminders h2, #upcoming-reminders li p.font-medium")
      expect(upcoming.map(&:text)).to eq(["Yesterday", "Water the plants", "Today", "Call the dentist"])
      expect(upcoming.last["class"]).to include("text-gray-500")
      expect(response.parsed_body.css("#overdue-reminders")).to be_empty
    end

    context "when the user shows only today" do
      it "lists only today's reminders and earlier ones not yet overdue" do
        travel_to Time.zone.parse("2026-10-19 18:00")
        sign_in create(:user, note_folders: ["Tabitha"], show_today_only: true)
        create(:reminder, line: "Water the plants (@8pm)", remind_at: Time.zone.parse("2026-10-19 20:00"))
        create(:reminder, line: "Weed the garden (@yesterday 8pm)", remind_at: Time.zone.parse("2026-10-18 20:00"))
        create(:reminder, line: "Call the dentist (@tomorrow 9am)", remind_at: Time.zone.parse("2026-10-20 09:00"))

        get root_path

        expect(response.parsed_body.css("#upcoming-reminders li p.font-medium").map(&:text))
          .to eq(["Weed the garden", "Water the plants"])
        expect(response.parsed_body.css("#reminder-filter [aria-pressed=true]").text).to eq("Today")
      end
    end

    it "lists reminders more than the user's overdue hours past as overdue, oldest first, with their dates" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"], overdue_after_hours: 6)
      create(:reminder, line: "Call the dentist (@9am)", remind_at: Time.zone.parse("2026-10-19 09:00"))
      create(:reminder, line: "Return library books (@Jan 5)", remind_at: Time.zone.parse("2026-01-05 08:00"))
      create(:reminder, line: "Get dry cleaning (@1pm)", remind_at: Time.zone.parse("2026-10-19 13:00"))

      get root_path

      overdue = response.parsed_body.css("#overdue-reminders li")
      expect(overdue.map { it.at_css("p.font-medium").text }).to eq(["Return library books", "Call the dentist"])
      expect(overdue.first.text).to include("Mon, Jan 5 at 8:00 AM")
      expect(response.parsed_body.css("#upcoming-reminders li p.font-medium").map(&:text)).to eq(["Get dry cleaning"])
    end

    it "lists the user's reminders whose time couldn't be understood" do
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Garden.md", line: "Water the plants (@whenever)", directive: "whenever",
        remind_at: nil)

      get root_path

      expect(response.parsed_body.css("#unscheduled-reminders").text).to include("Couldn't understand “whenever”")
    end

    context "when the user hasn't chosen any folders" do
      it "asks them to choose folders" do
        sign_in create(:user, note_folders: [])

        get root_path

        expect(response.parsed_body.css("#no-folders a").first["href"]).to eq(settings_path(anchor: "folders"))
      end
    end
  end

  describe "POST /reminders" do
    around do |example|
      Dir.mktmpdir do |dir|
        original_path = Rails.configuration.x.vault_path
        Rails.configuration.x.vault_path = dir
        example.run
      ensure
        Rails.configuration.x.vault_path = original_path
      end
    end

    let(:inbox) { Pathname(Rails.configuration.x.vault_path).join("Tabitha/Inbox.md") }

    it "adds the reminder to the end of the user's note and lists it at once" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"], reminders_note: "Tabitha/Inbox.md")

      post reminders_path, params: { reminder_addition: { text: " Call the  dentist ", time: "tomorrow 9am" } }
      follow_redirect!

      expect(inbox.read).to eq("- [ ] Call the dentist (@tomorrow 9am)\n")
      expect(Reminder.sole).to have_attributes(note_path: "Tabitha/Inbox.md", directive: "tomorrow 9am",
        remind_at: Time.zone.parse("2026-10-20 09:00"))
      expect(response.parsed_body.css("#upcoming-reminders li p.font-medium").map(&:text)).to eq(["Call the dentist"])
    end

    context "when the time isn't understood" do
      it "shows the error and adds nothing" do
        sign_in create(:user, note_folders: ["Tabitha"], reminders_note: "Tabitha/Inbox.md")

        post reminders_path, params: { reminder_addition: { text: "Call the dentist", time: "whenever" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("#new-reminder").text).to include("When isn't a time the app understands")
        expect(inbox).to_not exist
        expect(Reminder.count).to eq(0)
      end
    end
  end
end
