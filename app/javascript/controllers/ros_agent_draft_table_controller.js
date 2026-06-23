import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shell", "previousButton", "nextButton"]

  connect() {
    this.sync()
  }

  previous() {
    this.scrollBy(-this.stepSize())
  }

  next() {
    this.scrollBy(this.stepSize())
  }

  sync() {
    if (!this.hasShellTarget) return

    const maxScrollLeft = this.shellTarget.scrollWidth - this.shellTarget.clientWidth
    const currentScrollLeft = this.shellTarget.scrollLeft

    if (this.hasPreviousButtonTarget) {
      this.previousButtonTarget.disabled = currentScrollLeft <= 4
    }

    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = currentScrollLeft >= maxScrollLeft - 4
    }
  }

  scrollBy(delta) {
    if (!this.hasShellTarget) return

    this.shellTarget.scrollBy({
      left: delta,
      behavior: "smooth"
    })

    window.setTimeout(() => this.sync(), 250)
  }

  stepSize() {
    if (!this.hasShellTarget) return 320

    return Math.max(this.shellTarget.clientWidth * 0.75, 320)
  }
}
