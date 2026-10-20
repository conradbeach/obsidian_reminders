class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, :p256dh_key, :auth_key, presence: true
  validates :endpoint, uniqueness: true
  validate :endpoint_is_a_push_service

  # Browsers' push services; endpoints elsewhere are rejected so the server
  # can't be made to send requests to arbitrary hosts.
  PUSH_SERVICE_HOSTS = [
    "fcm.googleapis.com",
    "jmt17.google.com",
    "updates.push.services.mozilla.com",
    ".push.apple.com",
    ".notify.windows.com",
  ].freeze

  # Returns whether any subscription accepted the notification.
  def self.deliver_to_all(title:, body:, path:)
    find_each.map { it.deliver(title:, body:, path:) }.any?
  end

  # Returns whether the push service accepted the notification.
  def deliver(title:, body:, path:)
    WebPush.payload_send(
      message: { title:, options: { body:, data: { path: } } }.to_json,
      endpoint:,
      p256dh: p256dh_key,
      auth: auth_key,
      vapid: Rails.application.credentials.vapid,
    )
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
    false
  rescue WebPush::Error, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    Rails.logger.error("Push to subscription #{id} failed: #{e.message}")
    false
  end

  private

  def endpoint_is_a_push_service
    uri = endpoint_uri
    return if uri.is_a?(URI::HTTPS) && uri.host && PUSH_SERVICE_HOSTS.any? { push_service_host?(uri.host, it) }

    errors.add(:endpoint, "must be a browser push service")
  end

  def endpoint_uri
    URI.parse(endpoint.to_s)
  rescue URI::InvalidURIError
    nil
  end

  def push_service_host?(host, allowed)
    allowed.start_with?(".") ? host.end_with?(allowed) : host == allowed
  end
end
