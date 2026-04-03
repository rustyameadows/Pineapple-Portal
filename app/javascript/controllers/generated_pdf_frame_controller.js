import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "loading", "message", "detail"]

  connect() {
    this.loaded = false
    this.element.classList.add("is-loading")
    if (this.hasFrameTarget) this.frameTarget.setAttribute("aria-busy", "true")
    if (this.hasLoadingTarget) this.loadingTarget.hidden = false

    this.slowTimer = window.setTimeout(() => this.showSlowState(), 1800)
    this.stillRenderingTimer = window.setTimeout(() => this.showStillRenderingState(), 7000)
  }

  disconnect() {
    this.clearTimers()
  }

  frameLoaded() {
    this.loaded = true
    this.clearTimers()
    this.element.classList.remove("is-loading")
    this.element.classList.add("is-loaded")

    if (this.hasFrameTarget) this.frameTarget.removeAttribute("aria-busy")
    if (this.hasLoadingTarget) this.loadingTarget.hidden = true
  }

  showSlowState() {
    if (this.loaded) return
    if (this.hasMessageTarget) this.messageTarget.textContent = "Rendering live PDF..."
    if (this.hasDetailTarget) {
      this.detailTarget.textContent = "The first preview, or a freshly updated packet, can take a few seconds to build."
    }
  }

  showStillRenderingState() {
    if (this.loaded) return
    if (this.hasMessageTarget) this.messageTarget.textContent = "Still building your live PDF..."
    if (this.hasDetailTarget) {
      this.detailTarget.textContent = "Leave this page open. The preview will appear automatically as soon as the working PDF is ready."
    }
  }

  clearTimers() {
    window.clearTimeout(this.slowTimer)
    window.clearTimeout(this.stillRenderingTimer)
  }
}
