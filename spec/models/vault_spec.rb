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
      it "returns the note path, the line, and the directive's contents" do
        write_note("Home/Errands.md", "# Errands\n\n- [ ] Call the dentist (@tomorrow 9am)\n")

        expect(described_class.new(vault_path).reminders).to contain_exactly(
          { note_path: "Home/Errands.md", line: "- [ ] Call the dentist (@tomorrow 9am)", directive: "tomorrow 9am" },
        )
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

    context "when parentheses don't start with @" do
      it "doesn't treat them as a directive" do
        write_note("Errands.md", "Call the dentist (the one on Main St) @ 9am")

        expect(described_class.new(vault_path).reminders).to be_empty
      end
    end
  end
end
