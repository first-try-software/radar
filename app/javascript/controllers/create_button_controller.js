import { Controller } from "@hotwired/stimulus"

// Activates create button when required fields have content
export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.updateButtonState()
  }

  inputChanged() {
    this.updateButtonState()
  }

  updateButtonState() {
    // Find all required inputs (those with the required attribute)
    const requiredInputs = this.inputTargets.filter(input => input.hasAttribute("required"))
    
    // If no required inputs, check if any input has content (fallback behavior)
    const allRequiredFilled = requiredInputs.length > 0
      ? requiredInputs.every(input => input.value.trim() !== "")
      : this.inputTargets.some(input => input.value.trim() !== "")
    
    if (allRequiredFilled) {
      this.buttonTarget.classList.add("active")
    } else {
      this.buttonTarget.classList.remove("active")
    }
  }
}

