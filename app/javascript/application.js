// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Keeps what the page's auto-refresh would otherwise undo as it morphs: what someone opened or closed (the attributes
// an element lists in data-morph-preserve), and what they've typed.
addEventListener("turbo:before-morph-attribute", (event) => {
  const { target, detail: { attributeName } } = event
  const toggled = target.dataset.morphPreserve?.split(" ").includes(attributeName)
  const typed = target instanceof HTMLInputElement && attributeName === "value" && target.value !== target.defaultValue
  if (toggled || typed) event.preventDefault()
})
