require "rails_helper"

RSpec.describe "Reminders" do
  describe "GET /" do
    it "lists upcoming reminders grouped by day, soonest first" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Renew passport (@Dec 1)",
        remind_at: Time.zone.parse("2026-12-01 08:00"))
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@tomorrow 9am)",
        remind_at: Time.zone.parse("2026-10-20 09:00"))

      get root_path

      upcoming = response.parsed_body.css("#upcoming-reminders h2, #upcoming-reminders li p.font-medium").map(&:text)
      expect(upcoming).to eq(["Tomorrow", "Call the dentist", "Tue, Dec 1", "Renew passport"])
    end

    it "leaves out past reminders and other users' reminders" do
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Pay rent (@Oct 1)", remind_at: 1.day.ago)
      create(:reminder, note_path: "Conrad/Errands.md", line: "Change the oil (@tomorrow)", remind_at: 1.day.from_now)

      get root_path

      expect(response.parsed_body.css("#upcoming-reminders li")).to be_empty
    end

    context "when the user shows only today" do
      it "lists only the reminders still to come today" do
        travel_to Time.zone.parse("2026-10-19 18:00")
        sign_in create(:user, note_folders: ["Tabitha"], show_today_only: true)
        create(:reminder, note_path: "Tabitha/Garden.md", line: "Water the plants (@8pm)",
          remind_at: Time.zone.parse("2026-10-19 20:00"))
        create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@tomorrow 9am)",
          remind_at: Time.zone.parse("2026-10-20 09:00"))

        get root_path

        expect(response.parsed_body.css("#upcoming-reminders li p.font-medium").map(&:text)).to eq(["Water the plants"])
        expect(response.parsed_body.css("#reminder-filter [aria-pressed=true]").text).to eq("Today")
      end
    end

    it "lists every overdue reminder still in the vault, oldest first, with its date" do
      travel_to Time.zone.parse("2026-10-19 18:00")
      sign_in create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@9am)",
        remind_at: Time.zone.parse("2026-10-19 09:00"))
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Return library books (@Jan 5)",
        remind_at: Time.zone.parse("2026-01-05 08:00"))

      get root_path

      overdue = response.parsed_body.css("#overdue-reminders li")
      expect(overdue.map { it.at_css("p.font-medium").text }).to eq(["Return library books", "Call the dentist"])
      expect(overdue.first.text).to include("Mon, Jan 5 at 8:00 AM")
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

        expect(response.parsed_body.css("#no-folders a").first["href"]).to eq(edit_note_folders_path)
      end
    end
  end
end
