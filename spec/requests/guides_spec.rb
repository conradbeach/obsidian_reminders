require "rails_helper"

RSpec.describe "Guides" do
  describe "GET /guide" do
    it "explains the forms a reminder's time can take" do
      sign_in

      get guide_path

      expect(response.parsed_body.css("dt code").map(&:text)).to include("(@tomorrow 9am)", "(@every day until friday)")
    end
  end

  describe "the guide's examples" do
    it "are all understood" do
      sign_in

      get guide_path

      examples = response.parsed_body.css("dt code").map { it.text.delete_prefix("(@").delete_suffix(")") }
      expect(examples.reject { Reminder::Directive.new(it).time }).to be_empty
    end
  end

  describe "GET /" do
    it "links to the guide" do
      sign_in

      get root_path

      expect(response.parsed_body.at_css("header a[aria-label='Guide to writing reminders']")["href"]).to eq(guide_path)
    end
  end
end
