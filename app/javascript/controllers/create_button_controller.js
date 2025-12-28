import { Controller } from "@hotwired/stimulus"

// Activates create button when user types in form fields
export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.updateButtonState()
  }

  inputChanged() {
    this.updateButtonState()
  }

  updateButtonState() {
    const hasContent = this.inputTargets.some(input => input.value.trim() !== "")
    
    if (hasContent) {
      this.buttonTarget.classList.add("active")
    } else {
      this.buttonTarget.classList.remove("active")
    }
  }
}

