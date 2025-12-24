import { Controller } from "@hotwired/stimulus"

// Handles tab switching
export default class extends Controller {
  static targets = ["tab", "content"]
  static values = { active: String }

  connect() {
    // Set initial active tab if not already set
    if (this.activeValue) {
      this.showTab(this.activeValue)
    }
  }

  switch(event) {
    const tabName = event.currentTarget.dataset.tabsName
    this.showTab(tabName)
  }

  showTab(name) {
    this.tabTargets.forEach(tab => {
      tab.classList.toggle("active", tab.dataset.tabsName === name)
    })

    this.contentTargets.forEach(content => {
      content.classList.toggle("active", content.dataset.tabsName === name)
    })

    this.activeValue = name
  }
}

