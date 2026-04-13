import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toast", "buildToast", "buildMessage"]
  static values = {
    timeout: { type: Number, default: 3500 }
  }

  connect() {
    this.startTimers()
    this.startBuildPolling()
  }

  disconnect() {
    this.clearTimers()
    this.stopBuildPolling()
  }

  dismiss(event) {
    if (event) event.preventDefault()
    const toast = event?.currentTarget?.closest(".flash-toast") || event?.target || null
    if (toast) {
      if (this.hasBuildToastTarget && toast === this.buildToastTarget) {
        this.stopBuildPolling()
      }
      this.removeToast(toast)
    }
  }

  startTimers() {
    this.clearTimers()
    this.timeouts = this.toastTargets.map((toast) => {
      return setTimeout(() => {
        this.removeToast(toast)
      }, this.timeoutValue)
    })
  }

  clearTimers() {
    if (!this.timeouts) return
    this.timeouts.forEach((id) => clearTimeout(id))
    this.timeouts = []
  }

  startBuildPolling() {
    if (!this.hasBuildToastTarget) return

    const initialStatus = this.buildToastTarget.dataset.buildStatus || ""
    if (!this.isActiveStatus(initialStatus)) return

    this.buildPollTimer = window.setInterval(() => this.pollBuildStatus(), 4000)
    this.pollBuildStatus()
  }

  stopBuildPolling() {
    window.clearInterval(this.buildPollTimer)
    this.buildPollTimer = null
  }

  async pollBuildStatus() {
    if (!this.hasBuildToastTarget) return

    const statusUrl = this.buildToastTarget.dataset.buildStatusUrl
    if (!statusUrl) return

    try {
      const response = await fetch(statusUrl, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) return

      const data = await response.json()
      this.applyBuildStatus(data)
    } catch (_error) {
      // Leave the current toast text alone if polling fails.
    }
  }

  applyBuildStatus(data) {
    if (!this.hasBuildToastTarget) return

    const nextStatus = data.status || this.buildToastTarget.dataset.buildStatus || ""
    this.buildToastTarget.dataset.buildStatus = nextStatus

    if (this.hasBuildMessageTarget && data.progress_message) {
      this.buildMessageTarget.textContent = data.progress_message
    }

    if (!this.isActiveStatus(nextStatus)) {
      this.stopBuildPolling()
      this.removeToast(this.buildToastTarget)
    }
  }

  isActiveStatus(status) {
    return status === "pending" || status === "running"
  }

  removeToast(toast) {
    if (!toast || !toast.isConnected) return

    toast.classList.add("flash-toast--leaving")
    setTimeout(() => toast.remove(), 200)
  }
}
