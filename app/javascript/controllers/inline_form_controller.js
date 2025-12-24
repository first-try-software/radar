import { Controller } from "@hotwired/stimulus"

// Handles inline create forms (child projects, health updates, etc.)
export default class extends Controller {
  static targets = ["section", "toggle"]

  show() {
    if (this.hasSectionTarget && this.hasToggleTarget) {
      this.sectionTarget.hidden = false
      this.toggleTarget.classList.add("active")
      this.toggleTarget.textContent = "×"
      const firstInput = this.sectionTarget.querySelector("input[type='text']")
      firstInput?.focus()
    }
  }

  hide() {
    if (this.hasSectionTarget && this.hasToggleTarget) {
      this.sectionTarget.hidden = true
      this.toggleTarget.classList.remove("active")
      this.toggleTarget.textContent = "+"
    }
  }

  toggle() {
    if (this.hasSectionTarget) {
      if (this.sectionTarget.hidden) {
        this.show()
      } else {
        this.hide()
      }
    }
  }
}

