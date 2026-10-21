class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  # Folder paths from the vault's root: "Conrad", "Family/Errands".
  normalizes :note_folders,
    with: ->(folders) { folders.map { it.strip.delete_prefix("/").delete_suffix("/") }.compact_blank.uniq }

  validates :email_address, presence: true, uniqueness: true

  # Reminders from notes anywhere inside the user's folders.
  def reminders
    Reminder.in_vault.incomplete.in_folders(note_folders)
  end
end
