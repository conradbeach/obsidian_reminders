# One notification sent to one device, tracked from the push service accepting it to the device receiving and
# showing it, so a notification that never appeared shows where it was lost. The device reports back with the
# receipt token sent in the notification.
class PushDelivery < ApplicationRecord
  STAGES = ["received", "shown"].freeze

  belongs_to :push_subscription
  has_secure_token :receipt_token

  def receipt_path
    Rails.application.routes.url_helpers.push_delivery_receipt_path(receipt_token)
  end

  def receive(stage)
    update!("#{stage}_at": Time.current)
  end
end
