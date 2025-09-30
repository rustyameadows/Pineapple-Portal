import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toast"]
  static values = {
    timeout: { type: Number, default: 3500 }
  }

  connect() {
    this.startTimers()
  }

  disconnect() {
    this.clearTimers()
  }

  dismiss(event) {
    if (event) event.preventDefault()
    const toast = event?.currentTarget?.closest(".flash-toast") || event?.target || null
    if (toast) {
      toast.classList.add("flash-toast--leaving")
      setTimeout(() => toast.remove(), 200)
    }
  }

  startTimers() {
    this.clearTimers()
    this.timeouts = this.toastTargets.map((toast) => {
      return setTimeout(() => {
        toast.classList.add("flash-toast--leaving")
        setTimeout(() => toast.remove(), 200)
      }, this.timeoutValue)
    })
  }

  clearTimers() {
    if (!this.timeouts) return
    this.timeouts.forEach((id) => clearTimeout(id))
    this.timeouts = []
  }
}
