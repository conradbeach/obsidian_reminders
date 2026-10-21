require "rails_helper"

RSpec.describe "Authentication" do
  describe "visiting the reminders while signed out" do
    it "redirects to the sign in page" do
      get root_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "visiting background jobs while signed out" do
    it "redirects to the sign in page" do
      get "/jobs"

      expect(response).to redirect_to("/session/new")
    end
  end

  describe "visiting background jobs while signed in" do
    it "shows Mission Control" do
      sign_in

      get "/jobs"
      follow_redirect! while response.redirect?

      expect(response).to have_http_status(:ok)
    end
  end

  describe "signing in with valid credentials" do
    it "redirects to the page originally requested" do
      user = create(:user)
      get "/jobs"

      post "/session", params: { email_address: user.email_address, password: "password" }

      expect(response).to redirect_to("http://www.example.com/jobs/")
    end
  end

  describe "signing in with an invalid password" do
    it "returns to the sign in page with an error" do
      user = create(:user)

      post session_path, params: { email_address: user.email_address, password: "wrong" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end
  end

  describe "signing out" do
    it "ends the session" do
      sign_in

      delete session_path
      get root_path

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "requesting JSON with an API token" do
    it "authenticates as the token's user" do
      user = create(:user, note_folders: ["Tabitha"])
      create(:reminder, note_path: "Tabitha/Errands.md", line: "Call the dentist (@friday)")

      get reminders_path(format: :json), headers: { "Authorization" => "Bearer #{user.api_token}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["reminders"].pluck("text")).to eq(["Call the dentist"])
    end

    context "when the action isn't part of the API" do
      it "doesn't accept the token" do
        user = create(:user)

        get settings_path(format: :json), headers: { "Authorization" => "Bearer #{user.api_token}" }

        expect(response).to redirect_to(new_session_path)
      end
    end

    context "when the token is wrong" do
      it "responds unauthorized, even with a signed-in session" do
        sign_in

        get reminders_path(format: :json), headers: { "Authorization" => "Bearer wrong" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
