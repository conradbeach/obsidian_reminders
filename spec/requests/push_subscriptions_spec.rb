require "rails_helper"

RSpec.describe "Push subscriptions" do
  describe "POST /push_subscription" do
    let(:subscription_params) do
      { endpoint: "https://web.push.apple.com/abc", keys: { p256dh: "p256dh-key", auth: "auth-key" } }
    end

    context "when signed in" do
      it "saves the subscription for the current user" do
        user = sign_in

        post push_subscription_path, params: subscription_params, as: :json

        expect(response).to have_http_status(:created)
        expect(user.push_subscriptions.sole).to have_attributes(
          endpoint: "https://web.push.apple.com/abc", p256dh_key: "p256dh-key", auth_key: "auth-key",
        )
      end
    end

    context "when the device is already subscribed" do
      it "updates the existing subscription" do
        existing = create(:push_subscription, endpoint: "https://web.push.apple.com/abc", auth_key: "old-key")
        user = sign_in

        post push_subscription_path, params: subscription_params, as: :json

        expect(PushSubscription.sole).to have_attributes(id: existing.id, user:, auth_key: "auth-key")
      end
    end

    context "when the endpoint is not a browser push service" do
      it "rejects the subscription" do
        sign_in

        params = subscription_params.merge(endpoint: "https://internal.example.com/admin")

        post push_subscription_path, params:, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(PushSubscription.count).to eq(0)
      end
    end

    context "when signed out" do
      it "does not save the subscription" do
        post push_subscription_path, params: subscription_params, as: :json

        expect(PushSubscription.count).to eq(0)
      end
    end
  end

  describe "DELETE /push_subscription" do
    it "removes the current user's subscription for the endpoint" do
      user = sign_in
      create(:push_subscription, user:, endpoint: "https://web.push.apple.com/abc")

      delete push_subscription_path, params: { endpoint: "https://web.push.apple.com/abc" }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(PushSubscription.count).to eq(0)
    end

    it "leaves other users' subscriptions alone" do
      sign_in
      create(:push_subscription, endpoint: "https://web.push.apple.com/abc")

      delete push_subscription_path, params: { endpoint: "https://web.push.apple.com/abc" }, as: :json

      expect(PushSubscription.count).to eq(1)
    end
  end
end
