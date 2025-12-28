import { Controller } from "@hotwired/stimulus"

// Handles edit modal form submission with AJAX
// Works for both projects and initiatives
export default class extends Controller {
  static targets = ["modal", "form", "archiveCheckbox", "archiveLabel", "saveButton"]
  static values = { url: String, modelType: { type: String, default: "project" } }

  open() {
    if (this.hasModalTarget) {
      this.modalTarget.hidden = false
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.hidden = true
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  updateArchiveLabel() {
    if (this.hasArchiveCheckboxTarget && this.hasArchiveLabelTarget) {
      const modelName = this.modelTypeValue === "initiative" ? "initiative" : "project"
      this.archiveLabelTarget.textContent = this.archiveCheckboxTarget.checked
        ? `This ${modelName} is archived and hidden.`
        : "Click checkbox to archive"
    }
  }

  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    this.saveButtonTarget.textContent = "Saving..."
    this.saveButtonTarget.disabled = true

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
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
          Turbo.renderStreamMessage(text)
        } else {
          // Fallback: update DOM manually
          this.updateHeroSection(formData)
        }
        this.close()
      } else {
        const data = await response.json()
        const errorMsg = data.errors ? data.errors.join(", ") : "Failed to save"
        alert(errorMsg)
      }
    } catch (error) {
      console.error(error)
      alert("An error occurred. Please try again.")
    } finally {
      this.saveButtonTarget.textContent = "Save"
      this.saveButtonTarget.disabled = false
    }
  }

  updateHeroSection(formData) {
    const titleEl = document.querySelector("[data-project-title]")
    const taglineEl = document.querySelector("[data-project-tagline]")
    const contactEl = document.querySelector("[data-project-contact]")
    const pocEl = document.querySelector("[data-project-poc]")
    const heroActionsEl = document.querySelector(".project-hero__actions")
    const stickyActionsEl = document.querySelector(".sticky-header__actions")
    let heroBadge = document.querySelector("[data-archived-badge]")
    let stickyBadge = document.querySelector("[data-archived-badge-sticky]")

    // Detect model type from form data
    let modelType = "project"
    if (formData.has("initiative[name]")) {
      modelType = "initiative"
    } else if (formData.has("team[name]")) {
      modelType = "team"
    }
    const prefix = `${modelType}[`

    const name = formData.get(`${prefix}name]`)
    const description = formData.get(`${prefix}description]`)
    const poc = formData.get(`${prefix}point_of_contact]`)
    // Use getAll and check last value since hidden input comes before checkbox
    const archivedValues = formData.getAll(`${prefix}archived]`)
    const archived = archivedValues[archivedValues.length - 1] === "1"

    if (titleEl) titleEl.textContent = name
    if (taglineEl) {
      taglineEl.textContent = description
      taglineEl.hidden = !description
    }
    if (contactEl && pocEl) {
      pocEl.textContent = poc
      contactEl.hidden = !poc
    }

    // Update hero badge
    if (archived && !heroBadge && heroActionsEl) {
      heroBadge = document.createElement("span")
      heroBadge.className = "badge badge--archived"
      heroBadge.setAttribute("data-archived-badge", "")
      heroBadge.textContent = "ARCHIVED"
      heroActionsEl.insertBefore(heroBadge, heroActionsEl.firstChild)
    } else if (!archived && heroBadge) {
      heroBadge.remove()
    }

    // Update sticky header badge
    if (archived && !stickyBadge && stickyActionsEl) {
      stickyBadge = document.createElement("span")
      stickyBadge.className = "badge badge--archived"
      stickyBadge.setAttribute("data-archived-badge-sticky", "")
      stickyBadge.textContent = "ARCHIVED"
      stickyActionsEl.insertBefore(stickyBadge, stickyActionsEl.firstChild)
    } else if (!archived && stickyBadge) {
      stickyBadge.remove()
    }
  }
}

