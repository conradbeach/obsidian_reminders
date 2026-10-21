// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Keeps a reminder's notes open while the page's auto-refresh morphs it.
addEventListener("turbo:before-morph-attribute", (event) => {
  if (event.target instanceof HTMLDetailsElement && event.detail.attributeName === "open") event.preventDefault()
})
