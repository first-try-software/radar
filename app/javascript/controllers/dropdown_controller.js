import { Controller } from "@hotwired/stimulus"

// Handles dropdown menus (state dropdowns, etc.)
export default class extends Controller {
  static targets = ["menu", "toggle"]

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
}

