# A note in the vault, for checking off, identifying, and adding reminders' lines.
class Vault::Note
  TASK = /\A((?:[-*+]|\d+[.)])\s+)\[.\]\s*/
  LIST_ITEM = /\A((?:[-*+]|\d+[.)])\s+)/

  def initialize(path)
    @path = path
  end

  # Turns the line into a checked task ("- [x] Call the dentist (@friday)"), adding the checkbox if it has none.
  # Returns false, changing nothing, unless the note has exactly one line matching the reminder's.
  def check_off(line)
    lines = @path.exist? ? @path.read.lines : []
    matches = lines.each_index.select { lines[it].strip == line }
    return false unless matches.one?

    lines[matches.sole] = checked(lines[matches.sole])
    replace_with(lines.join)
    true
  end

  # Gives the last line matching the reminder's the block ID: when copies of a line share an ID, one gets a new one.
  # Returns false, changing nothing, if no line matches.
  def identify(line, block_id)
    lines = @path.exist? ? @path.read.lines : []
    index = lines.rindex { it.strip == line }
    return false unless index

    lines[index] = identified(lines[index], block_id)
    replace_with(lines.join)
    true
  end

  def append(line)
    content = @path.exist? ? @path.read : ""
    content += "\n" unless content.empty? || content.end_with?("\n")
    @path.dirname.mkpath
    replace_with("#{content}#{line}\n")
  end

  private

  # Keeps the line's indentation and line ending.
  def checked(raw_line)
    indentation, text, ending = raw_line.match(/\A(\s*)(.*?)(\r?\n)?\z/m).captures

    checked_text =
      if text.match?(TASK) then text.sub(TASK, '\1[x] ')
      elsif text.match?(LIST_ITEM) then text.sub(LIST_ITEM, '\1[x] ')
      else "- [x] #{text}"
      end

    "#{indentation}#{checked_text}#{ending}"
  end

  # Keeps the line's indentation and line ending.
  def identified(raw_line, block_id)
    text, ending = raw_line.match(/\A(.*?)(\r?\n)?\z/m).captures
    "#{text.rstrip.sub(Vault::BLOCK_ID, '')} ^#{block_id}#{ending}"
  end

  # Writes a hidden temporary file and renames it over the note, so the note is never left half-written.
  def replace_with(content)
    temporary = @path.dirname.join(".#{@path.basename}.reminders-tmp")
    temporary.write(content)
    temporary.rename(@path)
  end
end
