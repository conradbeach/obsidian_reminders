class CheckOffReminderJob < ApplicationJob
  retry_on Vault::Busy, wait: 5.seconds, attempts: 10
  # The reminder is gone if its line was edited or removed in the meantime.
  discard_on ActiveJob::DeserializationError

  # Skips a reminder that was undone.
  def perform(reminder)
    return if !reminder.completed_at || reminder.check_off_in_vault

    Rails.logger.warn("Reminder #{reminder.id} not checked off: its line isn't in #{reminder.note_path} exactly once")
  end
end
