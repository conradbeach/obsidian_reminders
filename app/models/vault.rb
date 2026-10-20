# The synced copy of the Obsidian vault on disk.
class Vault
  DIRECTIVE = /\(@([^)]+)\)/
  COMPLETED_TASK = /\A\s*[-*+]\s+\[[xX]\]/
  # Obsidian Sync's copy of a note it couldn't merge, which would repeat the note's reminders.
  CONFLICTED_COPY = /\(conflicted copy/i
  CODE_FENCE = /\A(```|~~~)/
  INLINE_CODE = /`[^`]*`/
  HEADING = /\A\#{1,6}\s+(.+?)(?:\s+\#+)?\z/

  def initialize(path)
    @path = Pathname(path)
  end

  # Attributes for each (@...) directive in the vault's notes, with the heading it's under, skipping completed tasks
  # and code, where "(@" is usually an instance variable. Hidden folders such as .obsidian and .trash aren't searched,
  # and conflicted copies are skipped.
  def reminders
    notes.flat_map { |note| reminders_in(note) }.uniq
  end

  private

  def notes
    @path.glob("**/*.md").reject { it.basename.to_s.match?(CONFLICTED_COPY) }
  end

  def reminders_in(note)
    note_path = note.relative_path_from(@path).to_s
    heading = nil

    prose_lines(note).flat_map do |line|
      heading = Regexp.last_match(1) if line.match(HEADING)
      next [] if line.match?(COMPLETED_TASK)

      line.gsub(INLINE_CODE, "").scan(DIRECTIVE).map do |(directive)|
        { note_path:, line:, directive: directive.strip, heading: }
      end
    end
  end

  # The note's lines, leaving out fenced code blocks.
  def prose_lines(note)
    in_code_block = false

    note.each_line.map(&:strip).reject do |line|
      fence = line.match?(CODE_FENCE)
      in_code_block = !in_code_block if fence
      fence || in_code_block
    end
  end
end
