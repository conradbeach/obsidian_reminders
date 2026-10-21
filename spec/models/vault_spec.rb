require "rails_helper"

RSpec.describe Vault do
  let(:vault_path) { Pathname(Dir.mktmpdir) }

  after { vault_path.rmtree }

  def write_note(path, content)
    file = vault_path.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  describe "#reminders" do
    context "when a note has a directive" do
      it "returns the note path, the line, the directive's contents, and the heading it's under" do
        write_note("Home/Errands.md", "# Errands\n\n- [ ] Call the dentist (@tomorrow 9am)\n")

        expect(described_class.new(vault_path).reminders).to contain_exactly(
          { note_path: "Home/Errands.md", line: "- [ ] Call the dentist (@tomorrow 9am)", directive: "tomorrow 9am",
            heading: "Errands", notes: nil },
        )
      end
    end

    context "when a note has several headings" do
      it "gives each directive the nearest heading above it, if any" do
        write_note("Errands.md", <<~MARKDOWN)
          Before any heading (@friday)
          # Errands
          ## This week ##
          Call the dentist (@friday)
          #not-a-heading (@friday)
        MARKDOWN

        expect(described_class.new(vault_path).reminders.pluck(:heading)).to eq([nil, "This week", "This week"])
      end
    end

    context "when lines are nested under a directive's line" do
      it "returns them as its notes, without their shared indentation, up to the next line that isn't nested" do
        write_note("Errands.md", <<~MARKDOWN)
          - [ ] Call the dentist (@friday)
            Ask about the crown
          \t- Bring the insurance card

            - Number: 555-0100
          - [ ] Pick up dry cleaning (@friday)
        MARKDOWN

        notes = described_class.new(vault_path).reminders.pluck(:notes)
        expect(notes).to eq(["Ask about the crown\n  - Bring the insurance card\n\n- Number: 555-0100", nil])
      end
    end

    context "when a line has more than one directive" do
      it "returns a reminder for each" do
        write_note("Errands.md", "Renew passport (@Nov 1) (@Dec 1)")

        expect(described_class.new(vault_path).reminders.pluck(:directive)).to eq(["Nov 1", "Dec 1"])
      end
    end

    context "when a task is checked off" do
      it "skips it" do
        write_note("Errands.md", "- [x] Call the dentist (@tomorrow 9am)\n- [ ] Pick up dry cleaning (@friday)")

        expect(described_class.new(vault_path).reminders.pluck(:directive)).to eq(["friday"])
      end
    end

    context "when a directive is in a hidden folder or a non-Markdown file" do
      it "skips it" do
        write_note(".trash/Old.md", "Deleted note (@tomorrow)")
        write_note(".obsidian/workspace.md", "Settings (@tomorrow)")
        write_note("Attachments/notes.txt", "Not a note (@tomorrow)")

        expect(described_class.new(vault_path).reminders).to be_empty
      end
    end

    context "when Obsidian Sync saved a conflicted copy of a note" do
      it "skips the copy" do
        write_note("Errands.md", "Call the dentist (@friday)")
        write_note("Errands (Conflicted copy).md", "Call the dentist (@friday)")

        expect(described_class.new(vault_path).reminders.pluck(:note_path)).to eq(["Errands.md"])
      end
    end

    context "when a directive is inside code" do
      it "skips it" do
        write_note("Notes.md", <<~MARKDOWN)
          ```ruby
          File.write(@checkpoint_file, data)
          ```
          Use `filter(@start_date, @end_date)` here (@friday)
        MARKDOWN

        expect(described_class.new(vault_path).reminders.pluck(:directive)).to eq(["friday"])
      end
    end

    context "when parentheses don't start with @" do
      it "doesn't treat them as a directive" do
        write_note("Errands.md", "Call the dentist (the one on Main St) @ 9am")

        expect(described_class.new(vault_path).reminders).to be_empty
      end
    end
  end

  describe "#check_off" do
    def check_off(line)
      described_class.new(vault_path).check_off(note_path: "Errands.md", line:)
    end

    context "when the line is an unchecked task" do
      it "checks it, leaving the rest of the note alone" do
        write_note("Errands.md", "# Errands\n- [ ] Call the dentist (@friday)\n- [ ] Return books (@monday)\n")

        expect(check_off("- [ ] Call the dentist (@friday)")).to be(true)
        expect(vault_path.join("Errands.md").read)
          .to eq("# Errands\n- [x] Call the dentist (@friday)\n- [ ] Return books (@monday)\n")
      end
    end

    context "when the line has no checkbox" do
      it "adds a checked one, keeping list markers, indentation, and line endings" do
        write_note("Errands.md",
          "- Call the dentist (@friday)\r\n  2. Return books (@monday)\r\nWater plants (@sunday)")

        check_off("- Call the dentist (@friday)")
        check_off("2. Return books (@monday)")
        check_off("Water plants (@sunday)")

        expect(vault_path.join("Errands.md").read)
          .to eq("- [x] Call the dentist (@friday)\r\n  2. [x] Return books (@monday)\r\n- [x] Water plants (@sunday)")
      end
    end

    context "when the checked-off line is scanned" do
      it "is a completed task with no reminder" do
        write_note("Errands.md", "  1. Return books (@monday)\n")

        check_off("1. Return books (@monday)")

        expect(described_class.new(vault_path).reminders).to be_empty
      end
    end

    context "when the note doesn't have the line exactly once" do
      it "changes nothing and returns false" do
        write_note("Errands.md", "Call the dentist (@friday)\nCall the dentist (@friday)\n")

        expect(check_off("Call the dentist (@friday)")).to be(false)
        expect(check_off("Return books (@monday)")).to be(false)
        expect(vault_path.join("Errands.md").read).to eq("Call the dentist (@friday)\nCall the dentist (@friday)\n")
      end
    end

    context "when the sync loop holds the vault's lock" do
      it "gives up with Busy, leaving the note alone" do
        stub_const("Vault::LOCK_TIMEOUT", 0.2.seconds)
        write_note("Errands.md", "Call the dentist (@friday)\n")

        vault_path.join(".reminders.lock").open(File::RDWR | File::CREAT) do |lock|
          lock.flock(File::LOCK_EX)
          expect { check_off("Call the dentist (@friday)") }.to raise_error(Vault::Busy)
        end
        expect(vault_path.join("Errands.md").read).to eq("Call the dentist (@friday)\n")
      end
    end
  end
end
