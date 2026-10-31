require "rails_helper"

RSpec.describe "Push delivery receipts" do
  describe "POST /push_deliveries/:receipt_token/receipt" do
    it "records that the device received the notification, without signing in" do
      freeze_time
      delivery = create(:push_subscription).deliveries.create!(title: "Take vitamins")

      post push_delivery_receipt_path(delivery.receipt_token), params: { stage: "received" }

      expect(response).to have_http_status(:no_content)
      expect(delivery.reload).to have_attributes(received_at: Time.current, shown_at: nil)
    end

    it "records that the device showed the notification" do
      delivery = create(:push_subscription).deliveries.create!(title: "Take vitamins")

      post push_delivery_receipt_path(delivery.receipt_token), params: { stage: "shown" }

      expect(delivery.reload.shown_at).to be_present
    end

    it "rejects an unknown stage" do
      delivery = create(:push_subscription).deliveries.create!(title: "Take vitamins")

      post push_delivery_receipt_path(delivery.receipt_token), params: { stage: "accepted" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(delivery.reload.accepted_at).to be_nil
    end

    it "rejects an unknown token" do
      post push_delivery_receipt_path("not-a-token"), params: { stage: "shown" }

      expect(response).to have_http_status(:not_found)
    end
  end
end
