require "rails_helper"

RSpec.describe "Push delivery completions" do
  describe "POST /push_deliveries/:receipt_token/completion" do
    it "marks the notification's reminder done, without signing in" do
      user = create(:user, note_folders: ["Tabitha"])
      reminder = create(:reminder, note_path: "Tabitha/Errands.md", notified_at: 1.minute.ago)
      delivery = create(:push_subscription, user:).deliveries.create!(title: "Call the dentist", reminder:)

      post push_delivery_completion_path(delivery.receipt_token)

      expect(response).to have_http_status(:no_content)
      expect(reminder.reload.completed_at).to be_present
    end

    context "when the reminder repeats" do
      it "moves it to its next occurrence only once, however often Done is tapped" do
        travel_to Time.zone.parse("2026-10-19 19:01")
        user = create(:user, note_folders: ["Tabitha"])
        reminder = create(:reminder, note_path: "Tabitha/Errands.md", directive: "every monday and thursday at 7pm",
          line: "Run (@every monday and thursday at 7pm)",
          remind_at: Time.zone.parse("2026-10-19 19:00"), notified_at: Time.zone.parse("2026-10-19 19:00"))
        delivery = create(:push_subscription, user:).deliveries.create!(title: "Run", reminder:)

        2.times { post push_delivery_completion_path(delivery.receipt_token) }

        expect(reminder.reload).to have_attributes(remind_at: Time.zone.parse("2026-10-22 19:00"), notified_at: nil,
          completed_at: nil)
      end
    end

    context "when the reminder is no longer in the recipient's folders" do
      it "leaves it undone" do
        user = create(:user, note_folders: ["Tabitha"])
        reminder = create(:reminder, note_path: "Conrad/Errands.md", notified_at: 1.minute.ago)
        delivery = create(:push_subscription, user:).deliveries.create!(title: "Call the dentist", reminder:)

        post push_delivery_completion_path(delivery.receipt_token)

        expect(response).to have_http_status(:not_found)
        expect(reminder.reload.completed_at).to be_nil
      end
    end

    context "when the notification wasn't for a reminder" do
      it "is not found" do
        delivery = create(:push_subscription).deliveries.create!(title: "Test notification from Reminders")

        post push_delivery_completion_path(delivery.receipt_token)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an unknown token" do
      it "is not found" do
        post push_delivery_completion_path("not-a-token")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
