import { Controller } from "@hotwired/stimulus"

// Handles project/initiative state dropdown with AJAX update
export default class extends Controller {
  static targets = ["menu", "badge"]
  static values = { url: String }

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  toggle(event) {
    event.stopPropagation()
    this.element.classList.toggle("open")
  }

  close() {
    this.element.classList.remove("open")
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  async select(event) {
    const state = event.currentTarget.dataset.state
    this.close()

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ state })
      })

      if (response.ok) {
        const contentType = response.headers.get("Content-Type")
        if (contentType && contentType.includes("turbo-stream")) {
          // Turbo will handle the stream automatically
          const text = await response.text()
          Turbo.renderStreamMessage(text)
        } else {
          // Fallback: reload the page
          window.location.reload()
        }
      }
    } catch (error) {
      console.error("Failed to update state:", error)
    }
  }
}

