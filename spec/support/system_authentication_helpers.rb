module SystemAuthenticationHelpers
  def sign_in_as(user)
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: "password"
    click_on "Sign in"
    expect(page).to have_content("Reminders")
  end
end

RSpec.configure do |config|
  config.include SystemAuthenticationHelpers, type: :system
end
