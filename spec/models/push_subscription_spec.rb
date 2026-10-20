require "rails_helper"

RSpec.describe PushSubscription do
  describe "endpoint validation" do
    it "accepts endpoints on browser push services" do
      endpoints = [
        "https://fcm.googleapis.com/fcm/send/abc",
        "https://jmt17.google.com/fcm/send/abc",
        "https://web.push.apple.com/abc",
        "https://updates.push.services.mozilla.com/wpush/v2/abc",
        "https://wns2-par02p.notify.windows.com/w/?token=abc",
      ]

      expect(endpoints.map { build(:push_subscription, endpoint: it) }).to all(be_valid)
    end

    it "rejects endpoints on other hosts" do
      subscription = build(:push_subscription, endpoint: "https://push.apple.com.attacker.example/abc")

      expect(subscription).to_not be_valid
      expect(subscription.errors[:endpoint]).to include("must be a browser push service")
    end

    it "rejects HTTPS endpoints without a host" do
      expect(build(:push_subscription, endpoint: "https:/fcm/send/abc")).to_not be_valid
    end

    it "rejects endpoints that are not HTTPS" do
      expect(build(:push_subscription, endpoint: "http://fcm.googleapis.com/fcm/send/abc")).to_not be_valid
    end
  end

  describe "#deliver" do
    context "when the push service accepts the notification" do
      it "sends the notification payload and returns true" do
        subscription = create(:push_subscription)
        allow(WebPush).to receive(:payload_send)

        result = subscription.deliver(title: "Expiring", body: "Wheat expires soon", path: "/")

        expect(result).to be(true)
        message = { title: "Expiring", options: { body: "Wheat expires soon", data: { path: "/" } } }.to_json
        expect(WebPush).to have_received(:payload_send)
          .with(hash_including(endpoint: subscription.endpoint, p256dh: "p256dh-key", auth: "auth-key", message:))
      end
    end

    context "when the subscription has expired" do
      it "deletes the subscription and returns false" do
        subscription = create(:push_subscription)
        response = instance_double(Net::HTTPGone, body: "")
        allow(WebPush).to receive(:payload_send)
          .and_raise(WebPush::ExpiredSubscription.new(response, "push.example.com"))

        result = subscription.deliver(title: "Expiring", body: "Wheat expires soon", path: "/")

        expect(result).to be(false)
        expect(described_class).to_not exist(subscription.id)
      end
    end

    context "when the push service fails" do
      it "keeps the subscription and returns false" do
        subscription = create(:push_subscription)
        response = instance_double(Net::HTTPServiceUnavailable, body: "")
        allow(WebPush).to receive(:payload_send)
          .and_raise(WebPush::PushServiceError.new(response, "push.example.com"))

        result = subscription.deliver(title: "Expiring", body: "Wheat expires soon", path: "/")

        expect(result).to be(false)
        expect(described_class).to exist(subscription.id)
      end
    end

    context "when the push service can't be reached" do
      it "keeps the subscription and returns false" do
        subscription = create(:push_subscription)
        allow(WebPush).to receive(:payload_send).and_raise(Net::OpenTimeout)

        result = subscription.deliver(title: "Expiring", body: "Wheat expires soon", path: "/")

        expect(result).to be(false)
        expect(described_class).to exist(subscription.id)
      end
    end
  end
end
