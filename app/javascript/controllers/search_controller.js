import { Controller } from "@hotwired/stimulus"

// Handles global search functionality
export default class extends Controller {
  static targets = ["input", "container", "column", "noResults", "createName", "resultsGrid", "resultsHeader"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  search() {
    const query = this.inputTarget.value.trim()
    const queryLower = query.toLowerCase()

    if (query === "") {
      this.containerTarget.classList.remove("open")
      return
    }

    this.containerTarget.classList.add("open")

    let totalVisible = 0

    this.columnTargets.forEach(column => {
      const items = column.querySelectorAll(".section__item--searchable")
      let columnVisible = 0

      items.forEach(item => {
        const name = item.dataset.searchName || ""
        const poc = item.dataset.searchPoc || ""
        const matches = name.includes(queryLower) || poc.includes(queryLower)
        item.hidden = !matches
        if (matches) columnVisible++
      })

      column.hidden = columnVisible === 0
      totalVisible += columnVisible
    })

    if (this.hasNoResultsTarget) {
      this.noResultsTarget.hidden = totalVisible > 0
      const capitalizedQuery = query.charAt(0).toUpperCase() + query.slice(1)
      if (this.hasCreateNameTarget) {
        this.createNameTarget.value = capitalizedQuery
        // Trigger input event so create-button controller updates
        this.createNameTarget.dispatchEvent(new Event("input", { bubbles: true }))
      }
    }

    if (this.hasResultsGridTarget) {
      this.resultsGridTarget.hidden = totalVisible === 0
    }
    if (this.hasResultsHeaderTarget) {
      this.resultsHeaderTarget.hidden = totalVisible === 0
    }
  }

  close() {
    this.containerTarget.classList.remove("open")
    this.inputTarget.value = ""
  }

  escape(event) {
    if (event.key === "Escape") {
      this.close()
      this.inputTarget.blur()
    }
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  async linkProject(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const url = button.dataset.linkUrl
    const projectId = button.dataset.projectId
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    // Disable button and show loading state
    const originalText = button.textContent
    button.textContent = "Linking..."
    button.disabled = true

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": token
        }
      })

      if (response.ok) {
        const contentType = response.headers.get("Content-Type")
        if (contentType && contentType.includes("turbo-stream")) {
          const text = await response.text()
          Turbo.renderStreamMessage(text)
        } else {
          // Fallback: update button to show linked state
          const listItem = button.closest(".section__item")
          button.remove()
          const badge = document.createElement("span")
          badge.className = "section__badge section__badge--linked"
          badge.textContent = "✓ Linked"
          listItem.appendChild(badge)
        }
        this.close()
      } else {
        const data = await response.json()
        const errorMsg = data.errors ? data.errors.join(", ") : "Failed to link project"
        this.showToast(errorMsg, "error")
        button.textContent = originalText
        button.disabled = false
      }
    } catch (error) {
      console.error("Failed to link project:", error)
      this.showToast("An error occurred. Please try again.", "error")
      button.textContent = originalText
      button.disabled = false
    }
  }

  showToast(message, type = "success") {
    const container = document.querySelector("[data-toast-container]")
    if (!container) return

    const toast = document.createElement("div")
    toast.className = `toast toast--${type}`
    toast.textContent = message

    container.appendChild(toast)

    requestAnimationFrame(() => {
      toast.classList.add("toast--visible")
    })

    setTimeout(() => {
      toast.classList.remove("toast--visible")
      setTimeout(() => toast.remove(), 300)
    }, 5000)

    toast.addEventListener("click", () => {
      toast.classList.remove("toast--visible")
      setTimeout(() => toast.remove(), 300)
    })
  }
}

