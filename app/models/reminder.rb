class Reminder < ApplicationRecord
  # Undelivered reminders are retried for this long. Reminders first found already this far past are never sent,
  # so editing an old note doesn't notify about it again.
  DELIVERY_WINDOW = 1.hour
  # A reminder missing from the vault is only deleted after this long, so one that briefly disappears (a scan reading
  # a note while Obsidian rewrites it) comes back with its original time rather than as a new reminder.
  MISSING_GRACE_PERIOD = 5.minutes
  # A reminder is the same reminder as long as its note, line, and directive are unchanged.
  IDENTITY = [:note_path, :line, :directive].freeze
  LIST_MARKER = /\A(?:[-*+]|\d+\.)\s+(?:\[.\]\s+)?/

  scope :in_vault, -> { where(missing_since: nil) }
  scope :upcoming, -> { where(remind_at: Time.current..).order(:remind_at) }
  # Past reminders still in the vault, which are open until they're checked off or deleted.
  scope :overdue, -> { where(remind_at: ...Time.current).order(:remind_at) }
  scope :today, -> { where(remind_at: Time.current.all_day) }
  scope :unscheduled, -> { where(remind_at: nil).order(:note_path, :line) }
  scope :in_folders, lambda { |folders|
    conditions = folders.map { arel_table[:note_path].matches("#{sanitize_sql_like(it)}/%", "\\") }
    conditions.any? ? where(conditions.reduce(:or)) : none
  }
  scope :due, -> { in_vault.where(notified_at: nil, remind_at: DELIVERY_WINDOW.ago..Time.current) }

  # Matches reminders to the vault's directives. Directives found for the first time are scheduled relative to now
  # ("tomorrow 9am"); reminders whose directive is gone, edited, or checked off are deleted once they've been missing
  # for the grace period. A reminder whose line is now under a different heading keeps its time.
  def self.sync(vault)
    unmatched = all.index_by { it.slice(*IDENTITY).symbolize_keys }

    transaction do
      vault.reminders.each do |attributes|
        reminder = unmatched.delete(attributes.slice(*IDENTITY)) || scheduled(attributes)
        reminder.update!(heading: attributes[:heading], missing_since: nil)
      end
      mark_missing(unmatched.values)
    end
  end

  def self.mark_missing(reminders)
    reminders.each { it.update!(missing_since: it.missing_since || Time.current) }
    where(missing_since: ..MISSING_GRACE_PERIOD.ago).delete_all
  end
  private_class_method :mark_missing

  def self.scheduled(attributes)
    new(attributes.slice(*IDENTITY).merge(remind_at: Directive.new(attributes[:directive]).time))
  end
  private_class_method :scheduled

  def self.notify_due
    due.find_each(&:notify)
  end

  # Stays unsent, to be retried, when none of the recipients' devices accept the notification.
  def notify
    subscriptions = PushSubscription.where(user: recipients)
    update!(notified_at: Time.current) if subscriptions.deliver_to_all(title: text, path: "/")
  end

  # The users whose folders contain the reminder's note.
  def recipients
    User.all.select { it.reminders.exists?(id) }
  end

  # The line without its list marker, checkbox, or directives.
  def text
    line.sub(LIST_MARKER, "").gsub(Vault::DIRECTIVE, "").squish.presence || note_name
  end

  def note_name
    File.basename(note_path, ".md")
  end

  # Opens the note at the reminder's heading, since Obsidian can't open a note at a line.
  def obsidian_url
    file = [note_path.delete_suffix(".md"), heading].compact.join("#")
    "obsidian://open?vault=#{ERB::Util.url_encode(Rails.configuration.x.vault_name)}&file=#{ERB::Util.url_encode(file)}"
  end
end
