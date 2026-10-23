import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Marking a reminder done: its circle fills in, the reminder folds away, and for a few seconds it can be undone. The
// server allows a little longer than the Undo button shows, so a slow connection still makes it in time.
export default class extends Controller {
  static targets = ["toast", "message"]

  async complete(event) {
    event.preventDefault()
    const form = event.target
    const button = form.querySelector("button")
    button.dataset.done = ""
    button.disabled = true

    const [response] = await Promise.all([this.#request("POST", form.action), wait(400)])
    if (!response?.ok) {
      delete button.dataset.done
      button.disabled = false
      return
    }

    await this.#fold(form.closest("li"))
    this.#offerUndo(form.action, event.params.text)
    this.#refresh()
  }

  async undo() {
    this.toastTarget.hidden = true
    await this.#request("DELETE", this.undoUrl)
    this.#refresh()
  }

  async #fold(row) {
    if (!matchMedia("(prefers-reduced-motion: reduce)").matches) {
      row.style.overflow = "hidden"
      await row.animate(
        [{ height: `${row.offsetHeight}px` }, { height: "0px", opacity: 0, paddingBlock: "0px" }],
        { duration: 250, easing: "ease-in" }
      ).finished
    }
    row.hidden = true
  }

  #offerUndo(url, text) {
    this.undoUrl = url
    this.messageTarget.textContent = `Done: ${text}`
    this.toastTarget.hidden = false
    clearTimeout(this.toastTimer)
    this.toastTimer = setTimeout(() => this.toastTarget.hidden = true, 5000)
  }

  #refresh() {
    Turbo.visit(window.location.href, { action: "replace" })
  }

  async #request(method, url) {
    try {
      return await fetch(url, {
        method,
        headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content ?? "" }
      })
    } catch {
      return null
    }
  }
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}
