import { Controller } from "@hotwired/stimulus"

// Handles sticky header visibility based on scroll position
export default class extends Controller {
  static targets = ["header", "trigger"]

  connect() {
    if (this.hasTriggerTarget) {
      this.observer = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting) {
              this.headerTarget.classList.add("sticky-header--visible")
            } else {
              this.headerTarget.classList.remove("sticky-header--visible")
            }
          })
        },
        { rootMargin: "0px", threshold: 0 }
      )
      this.observer.observe(this.triggerTarget)
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

