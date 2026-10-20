require "rails_helper"

RSpec.describe "Reminder filters" do
  describe "PATCH /reminder_filter" do
    it "remembers whether the user shows only today's reminders" do
      user = sign_in create(:user)

      patch reminder_filter_path, params: { show_today_only: true }
      expect(response).to redirect_to(root_path)
      expect(user.reload.show_today_only).to be(true)

      patch reminder_filter_path, params: { show_today_only: false }
      expect(user.reload.show_today_only).to be(false)
    end
  end
end
