class Reminder < ApplicationRecord
  # Undelivered reminders are retried for this long. Reminders first found already this far past are never sent,
  # so editing an old note doesn't notify about it again.
  DELIVERY_WINDOW = 1.hour
  LIST_MARKER = /\A(?:[-*+]|\d+\.)\s+(?:\[.\]\s+)?/

  scope :upcoming, -> { where(remind_at: Time.current..).order(:remind_at) }
  scope :unscheduled, -> { where(remind_at: nil).order(:note_path, :line) }
  scope :due, -> { where(notified_at: nil, remind_at: DELIVERY_WINDOW.ago..Time.current) }

  # Matches reminders to the vault's directives. Directives found for the first time are scheduled relative to now
  # ("tomorrow 9am"); reminders whose directive is gone, edited, or checked off are deleted.
  def self.sync(vault)
    unmatched = all.index_by { it.slice(:note_path, :line, :directive).symbolize_keys }

    transaction do
      vault.reminders.each do |attributes|
        unmatched.delete(attributes) || create!(**attributes, remind_at: Directive.new(attributes[:directive]).time)
      end
      where(id: unmatched.values.map(&:id)).delete_all
    end
  end

  def self.notify_due
    due.find_each(&:notify)
  end

  # Stays unsent, to be retried, when no device accepts the notification.
  def notify
    update!(notified_at: Time.current) if PushSubscription.deliver_to_all(title: text, body: note_name, path: "/")
  end

  # The line without its list marker, checkbox, or directives.
  def text
    line.sub(LIST_MARKER, "").gsub(Vault::DIRECTIVE, "").squish.presence || note_name
  end

  def note_name
    File.basename(note_path, ".md")
  end

  def obsidian_url
    vault = ERB::Util.url_encode(Rails.configuration.x.vault_name)
    "obsidian://open?vault=#{vault}&file=#{ERB::Util.url_encode(note_path)}"
  end
end
