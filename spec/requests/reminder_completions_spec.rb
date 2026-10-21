require "rails_helper"

RSpec.describe "Reminder completions" do
  describe "POST /reminders/:id/completion" do
    it "hides the reminder from the list" do
      sign_in create(:user, note_folders: ["Tabitha"])
      reminder = create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@friday)")

      post reminder_completion_path(reminder)
      follow_redirect!

      expect(reminder.reload.completed_at).to be_present
      expect(response.parsed_body.css("li")).to be_empty
    end

    it "doesn't complete another user's reminder" do
      sign_in create(:user, note_folders: ["Tabitha"])
      reminder = create(:reminder, note_path: "Conrad/Errands.md")

      post reminder_completion_path(reminder)

      expect(response).to have_http_status(:not_found)
      expect(reminder.reload.completed_at).to be_nil
    end

    context "when requesting JSON" do
      it "completes the reminder and responds with no content" do
        user = create(:user, note_folders: ["Tabitha"])
        reminder = create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@friday)")

        post reminder_completion_path(reminder, format: :json),
          headers: { "Authorization" => "Bearer #{user.api_token}" }

        expect(response).to have_http_status(:no_content)
        expect(reminder.reload.completed_at).to be_present
      end
    end
  end
end
