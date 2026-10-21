class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  # Folder paths from the vault's root: "Conrad", "Family/Errands".
  normalizes :note_folders,
    with: ->(folders) { folders.map { it.strip.delete_prefix("/").delete_suffix("/") }.compact_blank.uniq }

  validates :email_address, presence: true, uniqueness: true
  validates :overdue_after_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Reminders from notes anywhere inside the user's folders.
  def reminders
    Reminder.in_vault.incomplete.in_folders(note_folders)
  end

  # Reminders this long past are overdue. Until then they're listed on their day.
  def overdue_since
    overdue_after_hours.hours.ago
  end
end
