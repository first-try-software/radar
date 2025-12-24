import { Controller } from "@hotwired/stimulus"

// Handles toast notifications
export default class extends Controller {
  static values = {
    message: String,
    type: { type: String, default: "success" },
    duration: { type: Number, default: 10000 }
  }

  connect() {
    // If message value is set, show immediately
    if (this.messageValue) {
      this.show()
    }
  }

  show() {
    // Animate in
    requestAnimationFrame(() => {
      this.element.classList.add("toast--visible")
    })

    // Auto-dismiss
    this.dismissTimeout = setTimeout(() => {
      this.dismiss()
    }, this.durationValue)
  }

  dismiss() {
    if (this.dismissTimeout) {
      clearTimeout(this.dismissTimeout)
    }
    this.element.classList.remove("toast--visible")
    setTimeout(() => this.element.remove(), 300)
  }

  // Click to dismiss (unless clicking a link)
  click(event) {
    if (event.target.tagName !== "A") {
      this.dismiss()
    }
  }

  // Static method to create and show a toast
  static show(container, message, type = "success") {
    const toast = document.createElement("div")
    toast.className = `toast toast--${type}`
    toast.innerHTML = message
    toast.dataset.controller = "toast"
    toast.dataset.action = "click->toast#click"
    container.appendChild(toast)
  }
}

