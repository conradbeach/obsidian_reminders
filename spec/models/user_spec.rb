require "rails_helper"

RSpec.describe User do
  describe "validation" do
    context "when another user has the same email address" do
      it "is invalid, ignoring case and surrounding spaces" do
        create(:user, email_address: "me@example.com")
        user = build(:user, email_address: " ME@example.com ")

        expect(user).to_not be_valid
        expect(user.errors[:email_address]).to include("has already been taken")
      end
    end
  end

  describe "note folder normalization" do
    it "drops surrounding slashes, spaces, blank lines, and duplicates" do
      user = build(:user, note_folders: [" /Tabitha/ ", "", "Family/Errands", "Tabitha"])

      expect(user.note_folders).to eq(["Tabitha", "Family/Errands"])
    end
  end

  describe "reminders note normalization" do
    it "drops a leading slash and surrounding spaces, and adds a missing .md" do
      expect(build(:user, reminders_note: " /Tabitha/Inbox ").reminders_note).to eq("Tabitha/Inbox.md")
    end

    it "treats a blank note as none" do
      expect(build(:user, reminders_note: " ").reminders_note).to be_nil
    end
  end

  describe "reminders note validation" do
    context "when the note isn't in one of the user's folders" do
      it "is invalid" do
        user = build(:user, note_folders: ["Tabitha"], reminders_note: "Conrad/Inbox.md")

        expect(user).to_not be_valid
        expect(user.errors[:reminders_note]).to include("must be in one of your folders")
      end
    end

    context "when the note's path climbs out of the user's folder" do
      it "is invalid" do
        user = build(:user, note_folders: ["Tabitha"], reminders_note: "Tabitha/../../outside.md")

        expect(user).to_not be_valid
        expect(user.errors[:reminders_note]).to include("must be in one of your folders")
      end
    end

    context "when the note is in one of the user's folders, in any case" do
      it "is valid" do
        expect(build(:user, note_folders: ["Tabitha"], reminders_note: "tabitha/Home/Inbox.md")).to be_valid
      end
    end
  end

  describe "#reminders" do
    it "returns reminders from notes anywhere inside the user's folders, ignoring case" do
      user = create(:user, note_folders: ["Tabitha", "Family"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@friday)")
      create(:reminder, note_path: "tabitha/Home/Garden.md", line: "Water the plants (@friday)")
      create(:reminder, note_path: "Family/Trips.md", line: "Book the cabin (@friday)")
      create(:reminder, note_path: "Conrad/Tabitha gift.md", line: "Order flowers (@friday)")
      create(:reminder, note_path: "Tabitha notes.md", line: "Not in the folder (@friday)")

      expect(user.reminders.map(&:text)).to contain_exactly("Call the dentist", "Water the plants", "Book the cabin")
    end

    it "treats SQL wildcards in folder names literally" do
      user = create(:user, note_folders: ["My_Notes"])
      create(:reminder, note_path: "MyXNotes/Errands.md")

      expect(user.reminders).to be_empty
    end

    context "when the user has no folders" do
      it "returns no reminders" do
        create(:reminder)

        expect(create(:user).reminders).to be_empty
      end
    end
  end
end
