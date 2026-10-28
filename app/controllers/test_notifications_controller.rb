# Sends a notification to each of the user's devices now, to check they get reminders.
class TestNotificationsController < ApplicationController
  def create
    sent = Current.user.push_subscriptions.deliver_to_all(title: "Test notification from Reminders", path: "/settings")
    if sent
      redirect_to settings_path(anchor: "notifications"),
        notice: "Test notification sent. It should show up on your devices within a few seconds."
    else
      redirect_to settings_path(anchor: "notifications"),
        alert: "No device accepted the test notification. Turn on notifications on this device first."
    end
  end
end
