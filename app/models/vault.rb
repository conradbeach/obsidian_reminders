# The synced copy of the Obsidian vault on disk.
class Vault
  DIRECTIVE = /\(@([^)]+)\)/
  COMPLETED_TASK = /\A\s*[-*+]\s+\[[xX]\]/

  def initialize(path)
    @path = Pathname(path)
  end

  # Attributes for each (@...) directive in the vault's notes, skipping completed tasks. Hidden folders such as
  # .obsidian and .trash aren't searched.
  def reminders
    notes.flat_map { |note| reminders_in(note) }.uniq
  end

  private

  def notes
    @path.glob("**/*.md")
  end

  def reminders_in(note)
    note_path = note.relative_path_from(@path).to_s

    note.each_line.flat_map do |line|
      line = line.strip
      next [] if line.match?(COMPLETED_TASK)

      line.scan(DIRECTIVE).map { |(directive)| { note_path:, line:, directive: directive.strip } }
    end
  end
end
