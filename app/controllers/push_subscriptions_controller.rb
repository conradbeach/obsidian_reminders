class PushSubscriptionsController < ApplicationController
  def create
    subscription = PushSubscription.find_or_initialize_by(endpoint: params.require(:endpoint))
    subscription.update!(
      user: Current.user,
      p256dh_key: params.require(:keys).require(:p256dh),
      auth_key: params.require(:keys).require(:auth),
    )
    head :created
  end

  def destroy
    Current.user.push_subscriptions.find_by(endpoint: params.require(:endpoint))&.destroy
    head :no_content
  end
end
