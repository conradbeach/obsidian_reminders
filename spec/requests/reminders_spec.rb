require "rails_helper"

RSpec.describe "Reminders" do
  describe "GET /" do
    it "lists upcoming reminders soonest first, without past ones" do
      sign_in
      create(:reminder, line: "Renew passport (@Dec 1)", remind_at: 2.months.from_now)
      create(:reminder, line: "Call the dentist (@tomorrow 9am)", remind_at: 1.day.from_now)
      create(:reminder, line: "Pay rent (@Oct 1)", remind_at: 1.day.ago)

      get root_path

      upcoming = response.parsed_body.css("#upcoming-reminders li p.font-medium").map(&:text)
      expect(upcoming).to eq(["Call the dentist", "Renew passport"])
    end

    it "lists reminders whose time couldn't be understood" do
      sign_in
      create(:reminder, line: "Water the plants (@whenever)", directive: "whenever", remind_at: nil)

      get root_path

      expect(response.parsed_body.css("#unscheduled-reminders").text).to include("Couldn't understand “whenever”")
    end
  end
end
