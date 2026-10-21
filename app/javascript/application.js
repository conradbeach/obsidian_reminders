// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Keeps what the page's auto-refresh would otherwise undo as it morphs: notes someone opened, and what they've typed.
addEventListener("turbo:before-morph-attribute", (event) => {
  const { target, detail: { attributeName } } = event
  const opened = target instanceof HTMLDetailsElement && attributeName === "open"
  const typed = target instanceof HTMLInputElement && attributeName === "value" && target.value !== target.defaultValue
  if (opened || typed) event.preventDefault()
})
