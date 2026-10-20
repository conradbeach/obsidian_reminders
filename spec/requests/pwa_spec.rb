require "rails_helper"

RSpec.describe "Progressive web app" do
  describe "GET /manifest.json" do
    it "describes the installable app starting at the reminders list" do
      get pwa_manifest_path(format: :json)

      manifest = response.parsed_body
      expect(manifest).to include("name" => "Reminders", "start_url" => "/", "display" => "standalone")
    end
  end

  describe "GET /service-worker.js" do
    it "serves the push notification service worker" do
      get pwa_service_worker_path(format: :js)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("showNotification")
    end
  end
end
