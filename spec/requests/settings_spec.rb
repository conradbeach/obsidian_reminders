require "rails_helper"

RSpec.describe "Settings" do
  describe "GET /settings" do
    it "shows the user's folders, one per line, ready to edit" do
      sign_in create(:user, note_folders: ["Tabitha", "Family"])

      get settings_path

      expect(response.parsed_body.at_css("#folders textarea").text.strip).to eq("Tabitha\nFamily")
    end
  end
end
