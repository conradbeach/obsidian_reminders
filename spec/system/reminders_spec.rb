require "rails_helper"

RSpec.describe "Reminders" do
  it "shows upcoming reminders after signing in" do
    user = create(:user)
    create(:reminder, note_path: "Errands.md", line: "- [ ] Call the dentist (@tomorrow 9am)")

    visit root_path
    expect(page).to have_current_path(new_session_path)
    sign_in_as(user)

    within("#upcoming-reminders") do
      expect(page).to have_content("Call the dentist")
      expect(page).to have_link("Open", href: "obsidian://open?vault=Vault&file=Errands.md")
    end
  end
end
