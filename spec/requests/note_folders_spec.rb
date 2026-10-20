require "rails_helper"

RSpec.describe "Note folders" do
  describe "PATCH /note_folders" do
    it "saves the folders, one per line, for the signed-in user" do
      user = sign_in create(:user, note_folders: ["Old"])

      patch note_folders_path, params: { note_folders: "Tabitha\r\n/Family/Errands/\r\n" }

      expect(response).to redirect_to(root_path)
      expect(user.reload.note_folders).to eq(["Tabitha", "Family/Errands"])
    end
  end
end
