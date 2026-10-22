import { Controller } from "@hotwired/stimulus"

// The new reminder form, hidden until the + button opens it, and cleared and hidden again once a reminder is added.
export default class extends Controller {
  static targets = ["button", "form", "text", "errors"]

  toggle() {
    this.#show(this.formTarget.hidden)
    if (!this.formTarget.hidden) this.textTarget.focus()
  }

  submitted({ detail: { success } }) {
    if (!success) return

    this.formTarget.reset()
    if (this.hasErrorsTarget) this.errorsTarget.remove()
    this.#show(false)
  }

  #show(shown) {
    this.formTarget.hidden = !shown
    this.buttonTarget.setAttribute("aria-expanded", shown)
  }
}
