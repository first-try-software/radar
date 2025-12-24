import { Controller } from "@hotwired/stimulus"

// Handles modal dialogs
export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  open() {
    this.overlayTarget.hidden = false
  }

  close() {
    this.overlayTarget.hidden = true
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && !this.overlayTarget.hidden) {
      this.close()
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }
}

