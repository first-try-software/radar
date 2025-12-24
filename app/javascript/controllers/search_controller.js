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
}

