# A reminder added in the app, which goes at the end of the user's note for new reminders as a task with its block ID:
# "- [ ] Call the dentist (@tomorrow 9am) ^K3P9".
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
    Reminder.new(note_path:, line:, directive:, block_id:).tap(&:schedule).tap(&:save!)
  rescue Vault::Busy
    errors.add(:base, "The vault is busy syncing. Try again in a moment.")
    nil
  end

  private

  def note_path
    user.reminders_note
  end

  def line
    "- [ ] #{text.squish} (@#{directive}) ^#{block_id}"
  end

  def block_id
    @block_id ||= Reminder.new_block_id
  end

  def directive
    time.squish
  end

  def remind_at
    Reminder::Directive.new(directive).time
  end

  def time_understood
    # Worded like the list of reminders whose time couldn't be understood.
    errors.add(:base, "Needs a clearer time. Couldn't understand “#{directive}”.") unless remind_at
  end

  def note_chosen
    errors.add(:base, "Choose a note for new reminders in Settings first") unless note_path
  end
end
