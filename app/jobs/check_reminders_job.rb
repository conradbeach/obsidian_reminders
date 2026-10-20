class CheckRemindersJob < ApplicationJob
  def perform
    Reminder.sync(Vault.new(Rails.configuration.x.vault_path))
    Reminder.notify_due
  end
end
