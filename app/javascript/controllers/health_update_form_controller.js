import { Controller } from "@hotwired/stimulus"

// Handles health update form submission with optimistic UI
export default class extends Controller {
  static targets = [
    "form", "healthInput", "description", "submit",
    "stateInput", "stateDisplay", "stateDropdown",
    "updatesContainer", "updatesHeader", "updatesEmpty"
  ]
  static values = { stateUrl: String }

  connect() {
    this.closeStateDropdown = this.closeStateDropdown.bind(this)
    document.addEventListener("click", this.closeStateDropdown)
  }

  disconnect() {
    document.removeEventListener("click", this.closeStateDropdown)
  }

  // Called when health picker dispatches "selected" event
  healthSelected(event) {
    const value = event.detail.value
    if (this.hasHealthInputTarget) {
      this.healthInputTarget.value = value
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("btn--disabled")
    }
  }

  // Called when health picker dispatches "reset" event
  healthReset() {
    if (this.hasHealthInputTarget) {
      this.healthInputTarget.value = ""
    }
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("btn--disabled")
    }
  }

  // Handle Enter key in input - submit form
  handleInputKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      // Only submit if form is valid (health selected)
      if (this.hasHealthInputTarget && this.healthInputTarget.value && this.hasFormTarget) {
        this.performSubmit()
      }
    }
  }

  toggleStateDropdown(event) {
    event.stopPropagation()
    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.toggle("open")
    }
  }

  selectState(event) {
    const value = event.currentTarget.dataset.stateValue
    const label = value.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
    const cssClass = value.replace(/_/g, "-")

    if (this.hasStateInputTarget) {
      this.stateInputTarget.value = value
    }
    if (this.hasStateDisplayTarget) {
      this.stateDisplayTarget.textContent = label
      this.stateDisplayTarget.className = `state-pill state-pill--${cssClass}`
    }
    if (this.hasStateDropdownTarget) {
      this.stateDropdownTarget.classList.remove("open")
    }
  }

  closeStateDropdown(event) {
    if (this.hasStateDropdownTarget && !this.stateDropdownTarget.contains(event.target)) {
      this.stateDropdownTarget.classList.remove("open")
    }
  }

  // Called from form submit button
  submit(event) {
    event.preventDefault()
    this.performSubmit()
  }

  // Core submit logic - called by both submit() and handleTextareaKeydown()
  async performSubmit() {
    if (!this.hasFormTarget) return

    const form = this.formTarget
    const formData = new FormData(form)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    this.submitTarget.textContent = "Adding..."
    this.submitTarget.disabled = true

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": token
        },
        body: formData
      })

      const contentType = response.headers.get("Content-Type")

      if (response.ok) {
        if (contentType && contentType.includes("turbo-stream")) {
          const text = await response.text()
          window.Turbo.renderStreamMessage(text)
        } else {
          const data = await response.json()
          this.appendUpdateRow(formData)
          this.updateHealthWidget(data.health)
        }

        await this.updateStateIfNeeded()
        this.resetForm()
        this.showToast("Update added!", "success")
      } else {
        const data = await response.json()
        const errorMsg = data.errors ? data.errors.join(", ") : "Failed to add update"
        this.showToast(errorMsg, "error")
      }
    } catch (error) {
      console.error(error)
      this.showToast("An error occurred. Please try again.", "error")
    } finally {
      this.submitTarget.textContent = "Update"
      // Only re-enable if health is selected
      if (this.hasHealthInputTarget && this.healthInputTarget.value) {
        this.submitTarget.disabled = false
        this.submitTarget.classList.remove("btn--disabled")
      }
    }
  }

  async updateStateIfNeeded() {
    const newState = this.hasStateInputTarget ? this.stateInputTarget.value : null
    if (!newState || !this.stateUrlValue) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      await fetch(this.stateUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ state: newState })
      })

      const stateBadges = document.querySelectorAll("[data-state-badge]")
      const newStateLabel = newState.replace(/_/g, " ").toUpperCase()
      const newStateCss = newState.replace(/_/g, "-")
      stateBadges.forEach(badge => {
        badge.className = `badge state state--${newStateCss}`
        badge.textContent = newStateLabel
      })

      if (this.hasStateInputTarget) {
        this.stateInputTarget.value = ""
      }
    } catch (error) {
      console.error("Failed to update state:", error)
    }
  }

  appendUpdateRow(formData) {
    const healthValue = formData.get("health_update[health]")
    const descValue = formData.get("health_update[description]") || "—"

    const now = new Date()
    const displayDate = `${now.getMonth() + 1}/${now.getDate()}/${String(now.getFullYear()).slice(2)}`

    const newRow = document.createElement("div")
    newRow.className = "update-row"
    const healthLabelText = healthValue.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
    newRow.innerHTML = `
      <span class="update-row__date">${displayDate}</span>
      <span class="update-row__health">
        <span class="health-indicator health-indicator--${healthValue}"></span>
        <span class="health-text">${healthLabelText}</span>
      </span>
      <span class="update-row__description">${descValue}</span>
    `

    if (this.hasUpdatesHeaderTarget) {
      this.updatesHeaderTarget.hidden = false
    }
    if (this.hasUpdatesEmptyTarget) {
      this.updatesEmptyTarget.hidden = true
    }
    if (this.hasUpdatesContainerTarget) {
      this.updatesContainerTarget.insertBefore(newRow, this.updatesContainerTarget.firstChild)
    }
  }

  updateHealthWidget(health) {
    if (!health) return

    const healthDot = document.querySelector(".metric-widget__dot")
    const healthLabel = document.querySelector(".metric-widget--health .metric-widget__label")

    if (healthDot && healthLabel) {
      const newHealthClass = health.replace(/_/g, "-")
      healthDot.className = `metric-widget__dot metric-widget__dot--${newHealthClass}`
      healthLabel.className = `metric-widget__label metric-widget__label--${newHealthClass}`
      healthLabel.textContent = health.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase())
    }
  }

  resetForm() {
    if (this.hasDescriptionTarget) {
      this.descriptionTarget.value = ""
    }
    if (this.hasHealthInputTarget) {
      this.healthInputTarget.value = ""
    }

    const picker = this.element.querySelector("[data-controller*='health-picker']")
    if (picker) {
      picker.querySelectorAll(".health-picker__btn").forEach(btn => btn.classList.remove("selected"))
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("btn--disabled")
    }
  }

  showToast(message, type) {
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

    setTimeout(() => {
      toast.classList.remove("toast--visible")
      setTimeout(() => toast.remove(), 300)
    }, 10000)
  }
}
