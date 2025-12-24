import { Controller } from "@hotwired/stimulus"

// Handles flash message dismissal
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}

