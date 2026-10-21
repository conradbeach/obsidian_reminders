require "rails_helper"

RSpec.describe "Settings" do
  describe "GET /settings" do
    it "shows the user's folders, one per line, ready to edit" do
      sign_in create(:user, note_folders: ["Tabitha", "Family"])

      get settings_path

      expect(response.parsed_body.at_css("#folders textarea").text.strip).to eq("Tabitha\nFamily")
    end
  end

  describe "PATCH /settings" do
    it "saves the folders, one per line, and the overdue hours for the signed-in user" do
      user = sign_in create(:user, note_folders: ["Old"])

      patch settings_path,
        params: { user: { note_folders: "Tabitha\r\n/Family/Errands/\r\n", overdue_after_hours: "6" } }

      expect(response).to redirect_to(settings_path)
      expect(user.reload).to have_attributes(note_folders: ["Tabitha", "Family/Errands"], overdue_after_hours: 6)
    end

    context "when the overdue hours are negative" do
      it "shows the error and saves nothing" do
        user = sign_in create(:user, overdue_after_hours: 24)

        patch settings_path, params: { user: { note_folders: "Tabitha", overdue_after_hours: "-1" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.at_css("#errors").text)
          .to include("Overdue after hours must be greater than or equal to 0")
        expect(user.reload.overdue_after_hours).to eq(24)
      end
    end
  end
end
