import { Controller } from "@hotwired/stimulus"

// Handles AJAX project creation from global search
export default class extends Controller {
  static targets = ["form", "input", "name", "submit"]

  async create(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const submitBtn = this.submitTarget
    const originalText = submitBtn.textContent
    submitBtn.textContent = "Creating..."
    submitBtn.disabled = true

    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": formData.get("authenticity_token")
        },
        body: formData
      })

      const data = await response.json()

      if (response.ok) {
        this.showToast(`<a href="${data.url}">"${data.name}"</a> created!`, "success")
        this.resetForm()
        this.dispatch("created", { detail: { project: data } })
      } else {
        const errorMsg = data.errors ? data.errors.join(", ") : "Failed to create project"
        this.showToast(errorMsg, "error")
      }
    } catch (error) {
      console.error("Failed to create project:", error)
      this.showToast("An error occurred. Please try again.", "error")
    } finally {
      submitBtn.textContent = originalText
      submitBtn.disabled = false
    }
  }

  resetForm() {
    this.formTarget.reset()
    this.inputTargets.forEach(input => input.value = "")
  }

  showToast(message, type = "success") {
    const container = document.querySelector("[data-toast-container]")
    if (!container) return

    const toast = document.createElement("div")
    toast.className = `toast toast--${type}`
    toast.innerHTML = message
    toast.dataset.controller = "toast"
    toast.dataset.action = "click->toast#click"

    container.appendChild(toast)

    requestAnimationFrame(() => {
      toast.classList.add("toast--visible")
    })
  }
}

