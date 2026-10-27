class Reminder < ApplicationRecord
  include Identifiable

  # Undelivered reminders are retried for this long. Reminders first found already this far past are never sent,
  # so editing an old note doesn't notify about it again.
  DELIVERY_WINDOW = 1.hour
  # A reminder missing from the vault is only deleted after this long, so one that briefly disappears (a scan reading
  # a note while Obsidian rewrites it) comes back with its original time rather than as a new reminder.
  MISSING_GRACE_PERIOD = 5.minutes
  # How long marking a reminder done can be undone. Its note isn't checked off until then.
  UNDO_PERIOD = 10.seconds
  LIST_MARKER = /\A(?:[-*+]|\d+[.)])\s+(?:\[.\]\s+)?/

  scope :in_vault, -> { where(missing_since: nil) }
  scope :incomplete, -> { where(completed_at: nil) }
  scope :scheduled, -> { where.not(remind_at: nil).order(:remind_at) }
  scope :scheduled_since, ->(time) { where(remind_at: time..).order(:remind_at) }
  scope :scheduled_before, ->(time) { where(remind_at: ...time).order(:remind_at) }
  scope :through_today, -> { where(remind_at: ..Time.current.end_of_day) }
  scope :unscheduled, -> { where(remind_at: nil).order(:note_path, :line) }
  scope :in_folders, ->(folders) { folders.any? ? where(in_any_folder(folders)) : none }
  scope :outside_folders, ->(folders) { where.not(in_any_folder(folders)) if folders.any? }
  # All of them when there's no query.
  scope :matching, lambda { |query|
    where("line LIKE :query OR notes LIKE :query", query: "%#{sanitize_sql_like(query)}%") if query
  }
  scope :due, -> { in_vault.incomplete.where(notified_at: nil, remind_at: DELIVERY_WINDOW.ago..Time.current) }

  # Matches reminders to the vault's directives (see Matcher). Directives found for the first time are scheduled
  # relative to now ("tomorrow 9am"); reminders whose directive is gone or checked off are deleted once they've been
  # missing for the grace period.
  def self.sync(vault)
    matcher = Matcher.new(all.to_a)

    transaction do
      vault.reminders.each do |attributes|
        reminder, attributes = matcher.match(attributes)
        reminder.found_in_vault(attributes)
      end
      mark_missing(matcher.unmatched)
    end
  end

  def self.in_any_folder(folders)
    folders.map { arel_table[:note_path].matches("#{sanitize_sql_like(it)}/%", "\\") }.reduce(:or)
  end

  def self.mark_missing(reminders)
    reminders.each { it.update!(missing_since: it.missing_since || Time.current) }
    where(missing_since: ..MISSING_GRACE_PERIOD.ago).delete_all
  end
  private_class_method :mark_missing

  def self.notify_due
    due.find_each(&:notify)
  end

  # Takes on the line's current attributes. Its time is read, relative to now, when it's new, when its directive was
  # edited (which only its block ID lets it be followed through), and, until it's understood, each time, so it's
  # scheduled once the parser learns its wording. Once it's first scheduled, it gets a block ID if it can have one.
  # One marked done is wanted again if its line is edited rather than checked off, or comes back unchecked after
  # being checked off.
  def found_in_vault(attributes)
    unchecked = missing_since.present?
    assign_attributes(**attributes, missing_since: nil)
    self.completed_at = nil if line_edited? || unchecked
    if directive_changed? || !remind_at
      self.notified_at = nil
      schedule
    end
    save!
    identify_later if remind_at_before_last_save.nil? && identifiable?
  end

  # A repeating reminder moves on to its next occurrence, to be notified about again. Any other reminder, or a
  # repeating one past its last occurrence, is hidden at once and checked off in its note in the background, since
  # that waits on the sync and on the undo period.
  def complete
    undo = { undoable_until: UNDO_PERIOD.from_now, undo_remind_at: remind_at, undo_notified_at: notified_at }

    if (next_time = next_occurrence)
      update!(remind_at: next_time, notified_at: nil, **undo)
    else
      update!(completed_at: Time.current, **undo)
      CheckOffReminderJob.set(wait_until: undoable_until).perform_later(self)
    end
  end

  # Puts back a reminder marked done within the undo period. False once it's over.
  def undo_completion
    return false unless undoable_until&.future?

    update!(remind_at: undo_remind_at, notified_at: undo_notified_at, completed_at: nil, undoable_until: nil)
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

  # The line without its list marker, checkbox, directives, or block ID.
  def text
    line.sub(LIST_MARKER, "").sub(Vault::BLOCK_ID, "").gsub(Vault::DIRECTIVE, "").squish.presence || note_name
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
