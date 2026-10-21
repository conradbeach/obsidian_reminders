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

  it "hides a reminder as soon as it's marked done" do
    user = create(:user, note_folders: ["Tabitha"])
    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Pick up dry cleaning (@friday)")
    visit root_path
    sign_in_as(user)

    click_on "Mark “Pick up dry cleaning” done"

    expect(page).to have_content("Nothing coming up")
  end

  it "shows a reminder's notes when tapped, and keeps them open as the list refreshes" do
    user = create(:user, note_folders: ["Tabitha"])
    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Call the dentist (@friday)",
      notes: "Ask about the crown")
    visit root_path
    sign_in_as(user)
    expect(page).to have_no_content("Ask about the crown")

    find("summary", text: "Call the dentist").click
    expect(page).to have_content("Ask about the crown")

    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Pick up dry cleaning (@friday)")
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
    expect(page).to have_content("Pick up dry cleaning")
    expect(page).to have_content("Ask about the crown")
  end

  it "opens the new reminder form from the + button, keeps what's typed as the list refreshes, and closes once added" do
    user = create(:user, note_folders: ["Tabitha"], reminders_note: "Tabitha/Inbox.md")
    visit root_path
    sign_in_as(user)
    expect(page).to have_no_field("Reminder")

    click_on "New reminder"
    fill_in "Reminder", with: "Call the dentist"
    create(:reminder, note_path: "Tabitha/Errands.md", line: "- [ ] Pick up dry cleaning (@friday)")
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
    expect(page).to have_content("Pick up dry cleaning")
    expect(page).to have_field("Reminder", with: "Call the dentist")

    original_path = Rails.configuration.x.vault_path
    Dir.mktmpdir do |dir|
      Rails.configuration.x.vault_path = dir
      fill_in "When", with: "tomorrow 9am"
      click_on "Add"

      expect(page).to have_css("#upcoming-reminders", text: "Call the dentist")
      expect(page).to have_no_field("Reminder")
      click_on "New reminder"
      expect(page).to have_field("Reminder", with: "")
    ensure
      Rails.configuration.x.vault_path = original_path
    end
  end
end
