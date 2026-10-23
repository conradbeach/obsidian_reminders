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

  # Without a block ID of its own, on a line with no other reminder.
  def identifiable?
    !block_id && Vault.directives_in(line).one?
  end
end
