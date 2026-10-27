# A reminder's Obsidian block ID ("^K3P9" ending its line), which lets it be recognized after its line is reworded
# or moved to another note.
module Reminder::Identifiable
  extend ActiveSupport::Concern

  # How long a new reminder waits for its block ID, so the ID isn't added to a line someone's still typing.
  IDENTIFY_DELAY = 2.minutes
  BLOCK_ID_CHARACTERS = [*"A".."Z", *"0".."9"].freeze

  class_methods do
    def new_block_id
      loop do
        block_id = SecureRandom.alphanumeric(4, chars: BLOCK_ID_CHARACTERS)
        return block_id unless exists?(block_id:)
      end
    end
  end

  def identify_later
    IdentifyReminderJob.set(wait: IDENTIFY_DELAY).perform_later(self)
  end

  # Ends its line with a new block ID for the next sync to find, unless the line has changed in the meantime.
  def identify_in_vault
    Vault.synced.identify(note_path:, line:, block_id: self.class.new_block_id)
  end

  # Without a block ID of its own, on a line with no other reminder. Only a scheduled reminder that someone receives
  # is worth editing its note for: a line in a note outside everyone's folders, or with a time that can't be read, is
  # likely not meant as a reminder.
  def identifiable?
    !block_id && remind_at && Vault.directives_in(line).one? && recipients.any?
  end

  private

  # Changed other than by gaining a block ID.
  def line_edited?
    line_changed? && line_was&.sub(Vault::BLOCK_ID, "") != line.sub(Vault::BLOCK_ID, "")
  end
end
