# Finds the stored reminder for each of the vault's directives: by the block ID ending its line, or, for a line
# without one of its own yet, by its note, line, and directive. A copy of another reminder's line, block ID and all,
# doesn't count as having one.
class Reminder::Matcher
  def initialize(reminders)
    @by_block_id = reminders.select(&:block_id).index_by(&:block_id)
    @by_line = reminders.reject(&:block_id).index_by { line_identity(it) }
    @taken = @by_block_id.keys.to_set
  end

  # The matching reminder, or a new one, and the attributes to give it.
  def match(attributes)
    reminder = @by_block_id.delete(attributes[:block_id])
    attributes = attributes.merge(block_id: nil) if !reminder && @taken.include?(attributes[:block_id])
    @taken << attributes[:block_id] if attributes[:block_id]

    [reminder || @by_line.delete(line_identity(attributes)) || Reminder.new, attributes]
  end

  # The reminders that matched none of the directives.
  def unmatched
    @by_block_id.values + @by_line.values
  end

  private

  # A line just given a block ID still matches the reminder found before it had one.
  def line_identity(attributes)
    [attributes[:note_path], attributes[:line].sub(Vault::BLOCK_ID, ""), attributes[:directive]]
  end
end
