class CheckRemindersJob < ApplicationJob
  def perform
    Reminder.sync(Vault.synced)
    Reminder.notify_due
  end
end
