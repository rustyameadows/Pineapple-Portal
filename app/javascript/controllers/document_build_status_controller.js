import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "status"]
  static values = {
    statusUrl: String,
    initialStatus: String
  }

  connect() {
    this.currentStatus = this.initialStatusValue || ""
    if (!this.isActive(this.currentStatus)) return

    this.pollTimer = window.setInterval(() => this.pollStatus(), 4000)
    this.pollStatus()
  }

  disconnect() {
    window.clearInterval(this.pollTimer)
  }

  async pollStatus() {
    if (!this.hasStatusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) return

      const data = await response.json()
      this.applyStatus(data)
    } catch (_error) {
      // Leave the current row text alone if polling fails.
    }
  }

  applyStatus(data) {
    const nextStatus = data.status || this.currentStatus
    this.currentStatus = nextStatus

    if (this.hasProgressTarget && data.progress_message) {
      this.progressTarget.textContent = data.progress_message
    }

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = this.humanizeStatus(nextStatus)
      this.statusTarget.classList.remove(
        "generated-builder__build-status--pending",
        "generated-builder__build-status--running",
        "generated-builder__build-status--succeeded",
        "generated-builder__build-status--failed",
        "generated-builder__build-status--cancelled"
      )
      if (nextStatus) this.statusTarget.classList.add(`generated-builder__build-status--${nextStatus}`)
    }

    if (!this.isActive(nextStatus)) {
      window.clearInterval(this.pollTimer)
    }
  }

  isActive(status) {
    return status === "pending" || status === "running"
  }

  humanizeStatus(status) {
    if (!status) return ""
    return status.charAt(0).toUpperCase() + status.slice(1)
  }
}
