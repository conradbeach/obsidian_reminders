class Reminder < ApplicationRecord
  # Undelivered reminders are retried for this long. Reminders first found already this far past are never sent,
  # so editing an old note doesn't notify about it again.
  DELIVERY_WINDOW = 1.hour
  # A reminder missing from the vault is only deleted after this long, so one that briefly disappears (a scan reading
  # a note while Obsidian rewrites it) comes back with its original time rather than as a new reminder.
  MISSING_GRACE_PERIOD = 5.minutes
  # A reminder is the same reminder as long as its note, line, and directive are unchanged.
  IDENTITY = [:note_path, :line, :directive].freeze
  LIST_MARKER = /\A(?:[-*+]|\d+[.)])\s+(?:\[.\]\s+)?/

  scope :in_vault, -> { where(missing_since: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :scheduled, -> { where.not(remind_at: nil).order(:remind_at) }
  scope :scheduled_since, ->(time) { where(remind_at: time..).order(:remind_at) }
  scope :scheduled_before, ->(time) { where(remind_at: ...time).order(:remind_at) }
  scope :through_today, -> { where(remind_at: ..Time.current.end_of_day) }
  scope :unscheduled, -> { where(remind_at: nil).order(:note_path, :line) }
  scope :in_folders, lambda { |folders|
    conditions = folders.map { arel_table[:note_path].matches("#{sanitize_sql_like(it)}/%", "\\") }
    conditions.any? ? where(conditions.reduce(:or)) : none
  }
  scope :due, -> { in_vault.incomplete.where(notified_at: nil, remind_at: DELIVERY_WINDOW.ago..Time.current) }

  # Matches reminders to the vault's directives. Directives found for the first time are scheduled relative to now
  # ("tomorrow 9am"); reminders whose directive is gone, edited, or checked off are deleted once they've been missing
  # for the grace period. A reminder whose line is now under a different heading, or whose notes changed, keeps its
  # time. One whose time couldn't be understood is read again each time, so it's scheduled, relative to then, once the
  # parser learns its wording.
  def self.sync(vault)
    unmatched = all.index_by { it.slice(*IDENTITY).symbolize_keys }

    transaction do
      vault.reminders.each do |attributes|
        identity = attributes.slice(*IDENTITY)
        (unmatched.delete(identity) || new(identity)).found_in_vault(attributes)
      end
      mark_missing(unmatched.values)
    end
  end

  def self.mark_missing(reminders)
    reminders.each { it.update!(missing_since: it.missing_since || Time.current) }
    where(missing_since: ..MISSING_GRACE_PERIOD.ago).delete_all
  end
  private_class_method :mark_missing

  def self.notify_due
    due.find_each(&:notify)
  end

  # Schedules the reminder if it has no time yet, and keeps its heading and notes current.
  def found_in_vault(attributes)
    schedule unless remind_at
    update!(**attributes.slice(:heading, :notes), missing_since: nil)
  end

  # A repeating reminder moves on to its next occurrence, to be notified about again. Any other reminder, or a
  # repeating one past its last occurrence, is hidden at once and checked off in its note in the background, since
  # that waits on the sync.
  def complete
    if (next_time = next_occurrence)
      update!(remind_at: next_time, notified_at: nil)
    else
      update!(completed_at: Time.current)
      CheckOffReminderJob.perform_later(self)
    end
  end

  # Its time and, if it repeats, the day it starts on and any day it ends on, read from the directive relative to now.
  def schedule
    directive = Directive.new(self.directive)
    self.remind_at = directive.time
    self.starts_on = remind_at.to_date if remind_at && directive.recurrence
    self.ends_on = directive.ends_on
  end

  def recurrence
    @recurrence ||= Directive.new(directive, starts_on:).recurrence
  end

  def check_off_in_vault
    Vault.synced.check_off(note_path:, line:)
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

  def as_json(*)
    { id:, text:, remind_at:, recurring: recurrence.present?, note_path:, heading:, notes: }
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

  private

  def next_occurrence
    next_time = recurrence&.next_time(occurrence: remind_at, done_at: Time.current)
    next_time if next_time && (!ends_on || next_time.to_date <= ends_on)
  end
end
