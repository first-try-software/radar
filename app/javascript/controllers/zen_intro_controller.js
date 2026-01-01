import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tagline", "hero", "wordmark", "logo", "bottom"]

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const movieMode = urlParams.get("movie") === "true"

    if (movieMode) {
      // Add movie mode class to enable transitions
      this.element.classList.add("zen-dashboard--movie")
      this.runCinematicIntro()
    } else {
      this.showFinalState()
    }
  }

  showFinalState() {
    // Remove tagline from DOM entirely when not in movie mode
    this.taglineTarget.remove()
    
    // Show everything immediately in final position (no transitions)
    this.wordmarkTarget.classList.add("zen-wordmark--visible")
    this.logoTarget.classList.add("zen-logo-container--visible")
    this.heroTarget.classList.add("zen-dashboard__hero--top")
    this.bottomTarget.classList.add("zen-dashboard__bottom--visible")
  }

  runCinematicIntro() {
    // CSS handles initial hidden state in movie mode
    // Timeline:
    // 0-1s: Background only
    // 1s: Tagline fades in
    // 3s: Tagline fades out
    // 4s: Wordmark fades in (1s pause after tagline)
    // 6s: Logo fades in (wordmark visible for 2s)
    // 8s: Wordmark+logo rise to top
    // 10s: Health metrics + search rise

    // 1 second: tagline fades in
    setTimeout(() => {
      this.taglineTarget.classList.add("zen-tagline--visible")
    }, 2000)

    // 3 seconds: tagline fades out
    setTimeout(() => {
      this.taglineTarget.classList.remove("zen-tagline--visible")
    }, 4000)

    // 4 seconds: wordmark fades in (1 second after tagline fades)
    setTimeout(() => {
      this.wordmarkTarget.classList.add("zen-wordmark--visible")
    }, 5000)

    // 6 seconds: logo fades in (wordmark visible for 2s)
    setTimeout(() => {
      this.logoTarget.classList.add("zen-logo-container--visible")
    }, 6000)

    // 8 seconds: wordmark+logo rise to top
    setTimeout(() => {
      this.heroTarget.classList.add("zen-dashboard__hero--top")
    }, 9000)

    // 10 seconds: health metrics + search rise
    setTimeout(() => {
      this.bottomTarget.classList.add("zen-dashboard__bottom--visible")
    }, 11000)
  }
}
