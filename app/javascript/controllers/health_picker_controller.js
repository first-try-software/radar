import { Controller } from "@hotwired/stimulus"

// Handles health status picker (On Track / At Risk / Off Track)
export default class extends Controller {
  static targets = ["button", "input"]

  connect() {
    this.handleKeyboard = this.handleKeyboard.bind(this)
    document.addEventListener("keydown", this.handleKeyboard)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeyboard)
  }

  select(event) {
    const value = event.currentTarget.dataset.healthPickerValue
    this.setHealth(value)
  }

  setHealth(value) {
    // Deselect all buttons
    this.buttonTargets.forEach(btn => btn.classList.remove("selected"))

    // Select the clicked button
    const btn = this.buttonTargets.find(b => b.dataset.healthPickerValue === value)
    if (btn) {
      btn.classList.add("selected")
    }

    // Update hidden input
    if (this.hasInputTarget) {
      this.inputTarget.value = value
    }

    // Dispatch event for parent controllers to listen to
    this.dispatch("selected", { detail: { value } })
  }

  handleKeyboard(event) {
    // Don't trigger if typing in an input/textarea
    if (event.target.matches("input, textarea")) return

    switch (event.key) {
      case "1":
        this.setHealth("on_track")
        this.focusButton("on_track")
        break
      case "2":
        this.setHealth("at_risk")
        this.focusButton("at_risk")
        break
      case "3":
        this.setHealth("off_track")
        this.focusButton("off_track")
        break
    }
  }

  focusButton(value) {
    const btn = this.buttonTargets.find(b => b.dataset.healthPickerValue === value)
    if (btn) {
      btn.focus()
    }
  }

  reset() {
    this.buttonTargets.forEach(btn => btn.classList.remove("selected"))
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
    }
    this.dispatch("reset")
  }
}

