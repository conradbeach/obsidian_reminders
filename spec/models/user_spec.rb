require "rails_helper"

RSpec.describe User do
  describe "validation" do
    context "when another user has the same email address" do
      it "is invalid, ignoring case and surrounding spaces" do
        create(:user, email_address: "me@example.com")
        user = build(:user, email_address: " ME@example.com ")

        expect(user).to_not be_valid
        expect(user.errors[:email_address]).to include("has already been taken")
      end
    end
  end
end
