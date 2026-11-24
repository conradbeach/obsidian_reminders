# The Done button on a reminder's notification. Like a receipt, it's authorized by the delivery's receipt token, since
# the service worker has no session or CSRF token.
class PushDeliveries::CompletionsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  def create
    PushDelivery.find_by!(receipt_token: params.expect(:push_delivery_receipt_token)).complete_reminder
    head :no_content
  end
end
