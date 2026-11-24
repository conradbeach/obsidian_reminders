# One notification sent to one device, tracked from the push service accepting it to the device receiving and
# showing it, so a notification that never appeared shows where it was lost. The device reports back with the
# receipt token sent in the notification.
class PushDelivery < ApplicationRecord
  STAGES = ["received", "shown"].freeze

  belongs_to :push_subscription
  belongs_to :reminder, optional: true
  has_secure_token :receipt_token

  def receipt_path
    Rails.application.routes.url_helpers.push_delivery_receipt_path(receipt_token)
  end

  # What the service worker shows. The notification opens path when tapped.
  def message(path:)
    { title:, options: notification_options(path:), receipt: receipt_path }
  end

  # Marks the reminder done from its notification, as its recipient, unless that's already happened: a repeating
  # reminder marked done moves on to its next occurrence, which a second tap mustn't skip too.
  def complete_reminder
    reminder = push_subscription.user.reminders.find(reminder_id)
    reminder.complete if reminder.notified_at
  end

  def receive(stage)
    update!("#{stage}_at": Time.current)
  end

  private

  def notification_options(path:)
    return { data: { path: } } unless reminder

    completion = Rails.application.routes.url_helpers.push_delivery_completion_path(receipt_token)
    { data: { path:, completion: }, actions: [{ action: "complete", title: "Done" }] }
  end
end
