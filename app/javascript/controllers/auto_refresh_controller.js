import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Refreshes the page in place every so often while it's on screen, and as soon as it's back on screen, so changes
// from the vault and reminders coming due show up without a reload button (an installed iPhone app has none).
// The page morphs, so nothing flickers or scrolls.
export default class extends Controller {
  static values = { interval: Number }

  connect() {
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    this.start()
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    this.stop()
  }

  handleVisibilityChange() {
    if (document.visibilityState === "visible") {
      this.refresh()
      this.start()
    } else {
      this.stop()
    }
  }

  start() {
    this.stop()
    this.timer = setInterval(() => this.refresh(), this.intervalValue)
  }

  stop() {
    clearInterval(this.timer)
  }

  refresh() {
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
