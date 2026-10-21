import { Controller } from "@hotwired/stimulus"

// Clears the form once it's submitted successfully, so the page it returns to starts empty.
export default class extends Controller {
  reset({ detail: { success } }) {
    if (success) this.element.reset()
  }
}
