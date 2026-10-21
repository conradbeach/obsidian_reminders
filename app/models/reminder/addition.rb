# A reminder added in the app, which goes at the end of the user's note for new reminders as a task:
# "- [ ] Call the dentist (@tomorrow 9am)".
class Reminder::Addition
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :text, :string
  attribute :time, :string
  attr_accessor :user

  def self.human_attribute_name(attribute, options = {})
    { "text" => "Reminder", "time" => "When" }.fetch(attribute.to_s) { super }
  end

  validates :text, :time, presence: true
  validate :time_understood, if: -> { time.present? }
  validate :note_chosen

  # The new reminder, or nil if the addition isn't valid or the vault stayed busy.
  def save
    return unless valid?

    Vault.synced.append(note_path:, line:)
    Reminder.create_or_find_by!(note_path:, line:, directive:) { it.remind_at = remind_at }
  rescue Vault::Busy
    errors.add(:base, "The vault is busy syncing. Try again in a moment.")
    nil
  end

  private

  def note_path
    user.reminders_note
  end

  def line
    "- [ ] #{text.squish} (@#{directive})"
  end

  def directive
    time.squish
  end

  def remind_at
    Reminder::Directive.new(directive).time
  end

  def time_understood
    errors.add(:time, "isn't a time the app understands") unless remind_at
  end

  def note_chosen
    errors.add(:base, "Choose a note for new reminders in Settings first") unless note_path
  end
end
