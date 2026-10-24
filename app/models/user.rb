class User < ApplicationRecord
  has_secure_password
  # Authenticates the API's clients. Shown, and replaced on request, in Settings.
  has_secure_token :api_token
  has_many :sessions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  # Folder paths from the vault's root: "Conrad", "Family/Errands". Ignored folders are inside the user's folders,
  # holding notes whose reminders aren't theirs, like web clippings: "Conrad/Clippings".
  normalizes :note_folders, :ignored_folders,
    with: ->(folders) { folders.map { it.strip.delete_prefix("/").delete_suffix("/") }.compact_blank.uniq }

  # Where reminders added in the app go: "Conrad/Reminders.md".
  normalizes :reminders_note, with: lambda { |path|
    path = path.strip.delete_prefix("/")
    path.empty? || path.end_with?(".md") ? path.presence : "#{path}.md"
  }

  validates :email_address, presence: true, uniqueness: true
  validates :overdue_after_hours, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :reminders_note_in_folders, if: :reminders_note

  # Reminders from notes anywhere inside the user's folders, other than the ignored ones.
  def reminders
    reminders_including_completed.incomplete
  end

  def reminders_including_completed
    Reminder.in_vault.in_folders(note_folders).outside_folders(ignored_folders)
  end

  # Reminders this long past are overdue. Until then they're listed on their day.
  def overdue_since
    overdue_after_hours.hours.ago
  end

  private

  # Hidden folders aren't synced, and ".." could leave the folder, or the vault.
  def reminders_note_in_folders
    in_folder = in_any?(note_folders) && !in_any?(ignored_folders)
    return if in_folder && reminders_note.split("/").none? { it.start_with?(".") }

    errors.add(:reminders_note, "must be in one of your folders, outside the ignored ones")
  end

  def in_any?(folders)
    folders.any? { reminders_note.downcase.start_with?("#{it.downcase}/") }
  end
end
