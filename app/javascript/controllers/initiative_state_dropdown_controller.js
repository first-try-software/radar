import { Controller } from "@hotwired/stimulus"

// Handles initiative state dropdown with cascade confirmation modal
export default class extends Controller {
  static targets = ["menu", "badge", "cascadeModal", "cascadeStateName", "cascadeProjectCount"]
  static values = { url: String, relatedCount: Number }

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
    this.pendingState = null
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

  select(event) {
    const button = event.currentTarget
    const state = button.dataset.state
    const cascades = button.dataset.cascades === "true"
    const stateName = button.querySelector(".state-pill")?.textContent.trim() || state

    this.close()

    // If this state cascades and there are related projects, show confirmation modal
    if (cascades && this.relatedCountValue > 0) {
      this.showCascadeModal(state, stateName)
    } else {
      this.updateState(state, false)
    }
  }

  showCascadeModal(state, stateName) {
    this.pendingState = state
    if (this.hasCascadeStateNameTarget) {
      this.cascadeStateNameTarget.textContent = stateName
    }
    if (this.hasCascadeProjectCountTarget) {
      this.cascadeProjectCountTarget.textContent = this.relatedCountValue
    }
    if (this.hasCascadeModalTarget) {
      this.cascadeModalTarget.hidden = false
    }
  }

  closeCascade() {
    if (this.hasCascadeModalTarget) {
      this.cascadeModalTarget.hidden = true
    }
    this.pendingState = null
  }

  closeCascadeOnBackdrop(event) {
    if (event.target === this.cascadeModalTarget) {
      this.closeCascade()
    }
  }

  confirmCascade() {
    if (this.pendingState) {
      const state = this.pendingState
      this.closeCascade()
      this.updateState(state, true)
    }
  }

  skipCascade() {
    if (this.pendingState) {
      const state = this.pendingState
      this.closeCascade()
      this.updateState(state, false)
    }
  }

  async updateState(state, cascade) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("state", state)
    if (cascade) {
      url.searchParams.set("cascade", "true")
    }

    try {
      const response = await fetch(url.toString(), {
        method: "PATCH",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": token
        }
      })

      if (response.ok) {
        const contentType = response.headers.get("Content-Type")
        if (contentType && contentType.includes("turbo-stream")) {
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

