require "rails_helper"

RSpec.describe "Reminders" do
  it "shows upcoming reminders after signing in" do
    user = create(:user, note_folders: ["Tabitha"])
    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Call the dentist (@tomorrow 9am)")

    visit root_path
    expect(page).to have_current_path(new_session_path)
    sign_in_as(user)

    within("#upcoming-reminders") do
      expect(page).to have_content("Call the dentist")
      expect(page).to have_link("Errands", href: "obsidian://open?vault=Vault&file=Tabitha%2FErrands")
    end
  end

  it "refreshes the list when the app comes back on screen" do
    user = create(:user, note_folders: ["Tabitha"])
    visit root_path
    sign_in_as(user)
    expect(page).to have_content("Nothing coming up")

    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Pick up dry cleaning (@friday)")
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")

    expect(page).to have_content("Pick up dry cleaning")
  end
end
