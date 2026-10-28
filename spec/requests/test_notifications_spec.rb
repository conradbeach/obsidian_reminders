require "rails_helper"

RSpec.describe "Test notifications" do
  describe "POST /test_notification" do
    before { allow(WebPush).to receive(:payload_send).and_return(instance_double(Net::HTTPCreated, code: "201")) }

    context "when the user has notifications turned on" do
      it "sends a test notification to only their devices and says so" do
        user = sign_in
        create(:push_subscription, user:, endpoint: "https://web.push.apple.com/conrad")
        create(:push_subscription, endpoint: "https://web.push.apple.com/tabitha")

        post test_notification_path
        follow_redirect!

        expect(WebPush).to have_received(:payload_send).once
          .with(hash_including(endpoint: "https://web.push.apple.com/conrad"))
        expect(response.parsed_body.at_css("#notice").text).to include("Test notification sent")
      end
    end

    context "when none of the user's devices have notifications turned on" do
      it "says no device got it" do
        sign_in

        post test_notification_path
        follow_redirect!

        expect(WebPush).to_not have_received(:payload_send)
        expect(response.parsed_body.at_css("#alert").text).to include("No device accepted the test notification")
      end
    end
  end
end
