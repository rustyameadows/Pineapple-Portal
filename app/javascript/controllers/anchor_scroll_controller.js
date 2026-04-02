import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    offset: { type: Number, default: 32 }
  }

  connect() {
    this.boundScrollToHash = this.scrollToHash.bind(this)
    window.addEventListener("hashchange", this.boundScrollToHash)

    this.scrollToHash()
    this.timeout = setTimeout(() => this.scrollToHash(), 100)
  }

  disconnect() {
    window.removeEventListener("hashchange", this.boundScrollToHash)
    if (this.timeout) clearTimeout(this.timeout)
    if (this.cleanupTimeout) clearTimeout(this.cleanupTimeout)
  }

  scrollToHash() {
    const hash = window.location.hash
    if (!hash || hash.length <= 1) return

    const target = document.getElementById(hash.slice(1))
    if (!target || !this.element.contains(target)) return

    requestAnimationFrame(() => {
      const top = target.getBoundingClientRect().top + window.scrollY - this.offsetValue
      window.scrollTo({ top: Math.max(top, 0), behavior: "smooth" })
      this.scheduleHashCleanup(hash)
    })
  }

  scheduleHashCleanup(hash) {
    if (this.cleanupTimeout) clearTimeout(this.cleanupTimeout)

    this.cleanupTimeout = setTimeout(() => {
      if (window.location.hash !== hash) return

      const cleanUrl = `${window.location.pathname}${window.location.search}`
      window.history.replaceState(window.history.state, "", cleanUrl)
    }, 250)
  }
}
