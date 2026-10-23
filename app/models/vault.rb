# The synced copy of the Obsidian vault on disk.
class Vault
  DIRECTIVE = /\(@([^)]+)\)/
  # An Obsidian block ID ending a line: "Call the dentist (@friday) ^K3P9". It identifies a reminder through edits.
  BLOCK_ID = /\s+\^([A-Za-z0-9-]+)\z/
  COMPLETED_TASK = /\A\s*(?:[-*+]|\d+[.)])\s+\[[xX]\]/
  # Shared with the obsidian accessory's sync loop (config/obsidian/start.sh), so the app never edits a note while
  # Obsidian Headless is syncing it. Dot-files aren't synced.
  LOCK_FILE = ".reminders.lock".freeze
  LOCK_TIMEOUT = 10.seconds

  class Busy < StandardError; end
  # Obsidian Sync's copy of a note it couldn't merge, which would repeat the note's reminders.
  CONFLICTED_COPY = /\(conflicted copy/i
  CODE_FENCE = /\A(```|~~~)/
  INLINE_CODE = /`[^`]*`/
  HEADING = /\A\#{1,6}\s+(.+?)(?:\s+\#+)?\z/
  TAB = "    ".freeze

  def self.synced
    new(Rails.configuration.x.vault_path)
  end

  def initialize(path)
    @path = Pathname(path)
  end

  # The directives in a line, leaving out any in inline code.
  def self.directives_in(line)
    line.gsub(INLINE_CODE, "").scan(DIRECTIVE).map { it.first.strip }
  end

  # Attributes for each (@...) directive in the vault's notes, with the heading it's under and the line's block ID,
  # skipping completed tasks and code, where "(@" is usually an instance variable. A line with several directives has
  # no block ID, since one ID can't tell its reminders apart. Hidden folders such as .obsidian and .trash aren't
  # searched, and conflicted copies are skipped.
  def reminders
    notes.flat_map { |note| reminders_in(note) }.uniq
  end

  # Checks off the reminder's line in its note. Returns whether the note had exactly one such line to check off.
  def check_off(note_path:, line:)
    synchronize { Note.new(@path.join(note_path)).check_off(line) }
  end

  # Ends the reminder's line with the block ID, replacing any it has. Returns whether the note had such a line.
  def identify(note_path:, line:, block_id:)
    synchronize { Note.new(@path.join(note_path)).identify(line, block_id) }
  end

  # Adds the line to the end of the note, creating the note if need be.
  def append(note_path:, line:)
    synchronize { Note.new(@path.join(note_path)).append(line) }
  end

  private

  # Raises Busy if the sync loop holds the lock for longer than the timeout.
  def synchronize
    @path.join(LOCK_FILE).open(File::RDWR | File::CREAT) do |lock|
      deadline = LOCK_TIMEOUT.from_now
      until lock.flock(File::LOCK_EX | File::LOCK_NB)
        raise Busy if Time.current > deadline

        sleep 0.1
      end
      yield
    end
  end

  def notes
    @path.glob("**/*.md").reject { it.basename.to_s.match?(CONFLICTED_COPY) }
  end

  def reminders_in(note)
    note_path = note.relative_path_from(@path).to_s
    lines = prose_lines(note)
    heading = nil

    lines.each_with_index.flat_map do |raw_line, index|
      line = raw_line.strip
      heading = Regexp.last_match(1) if line.match(HEADING)
      next [] if line.match?(COMPLETED_TASK)

      reminders_on(line, lines, index, note_path:, heading:)
    end
  end

  # A reminder for each of the directives in the line at index.
  def reminders_on(line, lines, index, **attributes)
    directives = self.class.directives_in(line)
    block_id = line[BLOCK_ID, 1] if directives.one?
    directives.map { { **attributes, line:, directive: it, notes: notes_under(lines, index), block_id: } }
  end

  # The note's lines, leaving out fenced code blocks.
  def prose_lines(note)
    in_code_block = false

    note.each_line(chomp: true).reject do |line|
      fence = line.strip.match?(CODE_FENCE)
      in_code_block = !in_code_block if fence
      fence || in_code_block
    end
  end

  # The lines nested under the one at index: indented further, with any blank lines between them.
  def notes_under(lines, index)
    depth = indentation(lines[index])
    nested = lines.drop(index + 1).take_while { it.blank? || indentation(it) > depth }
    dedent(nested.reverse.drop_while(&:blank?).reverse).presence
  end

  # The lines as one string, without their shared indentation.
  def dedent(lines)
    lines = lines.map { it.sub(/\A\s+/) { |indent| indent.gsub("\t", TAB) }.rstrip }
    shared = lines.compact_blank.map { indentation(it) }.min.to_i
    lines.map { it.delete_prefix(" " * shared) }.join("\n")
  end

  def indentation(line)
    line[/\A\s*/].gsub("\t", TAB).length
  end
end
