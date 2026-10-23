import { Controller } from "@hotwired/stimulus"

// The search field, hidden until the search button opens it. It searches as you type, and closing it shows
// everything again.
export default class extends Controller {
  static targets = ["button", "form", "input"]

  toggle() {
    const shown = this.formTarget.hidden
    this.formTarget.hidden = !shown
    this.buttonTarget.setAttribute("aria-expanded", shown)

    if (shown) {
      this.inputTarget.focus()
    } else if (this.inputTarget.value) {
      this.inputTarget.value = ""
      this.formTarget.requestSubmit()
    }
  }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.formTarget.requestSubmit(), 250)
  }
}
