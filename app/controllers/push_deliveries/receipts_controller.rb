# A device reporting that it received, or showed, a notification. Its service worker has no session or CSRF token,
# so the delivery's receipt token, sent only in the notification, is what authorizes it.
class PushDeliveries::ReceiptsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    stage = params.expect(:stage)
    return head :unprocessable_content unless PushDelivery::STAGES.include?(stage)

    PushDelivery.find_by!(receipt_token: params.expect(:push_delivery_receipt_token)).receive(stage)
    head :no_content
  end
end
