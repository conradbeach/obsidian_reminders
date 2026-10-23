class IdentifyReminderJob < ApplicationJob
  retry_on Vault::Busy, wait: 5.seconds, attempts: 10
  # The reminder is gone if its line was edited or removed in the meantime.
  discard_on ActiveJob::DeserializationError

  def perform(reminder)
    reminder.identify_in_vault if reminder.identifiable?
  end
end
