# Find buttons and links by their aria-label, like the icon-only Done button.
Capybara.enable_aria_label = true

RSpec.configure do |config|
  config.before(type: :system) do
    driven_by :playwright, options: {
      browser_type: :chromium,
      headless: true,
      playwright_cli_executable_path: Rails.root.join("node_modules/.bin/playwright").to_s,
    }
  end
end
