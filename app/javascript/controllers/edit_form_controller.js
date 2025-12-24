import { Controller } from "@hotwired/stimulus"

// Handles edit modal form submission with AJAX
export default class extends Controller {
  static targets = ["modal", "form", "archiveCheckbox", "archiveLabel", "saveButton"]
  static values = { url: String }

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
      this.archiveLabelTarget.textContent = this.archiveCheckboxTarget.checked
        ? "This project is archived and hidden."
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
    const actionsEl = document.querySelector(".project-hero__actions")
    let archivedBadge = document.querySelector("[data-archived-badge]")

    const name = formData.get("project[name]")
    const description = formData.get("project[description]")
    const poc = formData.get("project[point_of_contact]")
    const archived = formData.get("project[archived]") === "1"

    if (titleEl) titleEl.textContent = name
    if (taglineEl) {
      taglineEl.textContent = description
      taglineEl.hidden = !description
    }
    if (contactEl && pocEl) {
      pocEl.textContent = poc
      contactEl.hidden = !poc
    }

    if (archived && !archivedBadge) {
      archivedBadge = document.createElement("span")
      archivedBadge.className = "badge badge--archived"
      archivedBadge.setAttribute("data-archived-badge", "")
      archivedBadge.textContent = "ARCHIVED"
      actionsEl.insertBefore(archivedBadge, actionsEl.firstChild)
    } else if (!archived && archivedBadge) {
      archivedBadge.remove()
    }
  }
}

