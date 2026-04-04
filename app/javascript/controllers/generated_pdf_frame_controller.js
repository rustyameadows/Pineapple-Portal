import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "loading", "message", "detail", "banner", "bannerMessage", "bannerDetail"]
  static values = {
    statusUrl: String,
    initialStatus: String,
    initialWorkingAvailable: Boolean,
    initialViewerToken: String,
    initialRefreshError: String
  }

  connect() {
    this.loaded = false
    this.currentStatus = this.initialStatusValue || "missing"
    this.currentViewerToken = this.initialViewerTokenValue || null
    this.workingAvailable = this.initialWorkingAvailableValue
    this.blockingLoad = !this.workingAvailable

    if (this.hasFrameTarget && this.workingAvailable) this.frameTarget.setAttribute("aria-busy", "true")
    this.applyStatus({
      status: this.currentStatus,
      working_available: this.workingAvailable,
      viewer_token: this.currentViewerToken,
      refresh_error: this.initialRefreshErrorValue
    })

    this.pollTimer = window.setInterval(() => this.pollStatus(), 4000)
    this.pollStatus()
  }

  disconnect() {
    this.clearTimers()
    window.clearInterval(this.pollTimer)
  }

  frameLoaded() {
    this.loaded = true
    if (this.blockingLoad) {
      this.hideLoading()
      this.blockingLoad = false
    }
    if (this.hasFrameTarget) this.frameTarget.removeAttribute("aria-busy")
  }

  async pollStatus() {
    if (!this.hasStatusUrlValue) return

    try {
      const response = await fetch(this.statusUrlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return

      const data = await response.json()
      this.applyStatus(data)
    } catch (_error) {
      // Leave the current preview and status text alone if polling fails.
    }
  }

  applyStatus(data) {
    const previousWorkingAvailable = this.workingAvailable
    const nextStatus = data.status || "missing"
    const nextWorkingAvailable = !!data.working_available
    const nextViewerToken = data.viewer_token || null
    const nextViewerPath = data.viewer_path || null
    const nextError = data.refresh_error || null

    this.currentStatus = nextStatus
    this.workingAvailable = nextWorkingAvailable

    if (nextStatus === "refreshing" && nextWorkingAvailable) {
      this.showBanner(
        "A newer live PDF is being prepared.",
        "Showing the last live version until the refreshed packet is ready."
      )
    } else if (nextStatus === "failed" && nextWorkingAvailable) {
      this.showBanner(
        "Live PDF refresh failed.",
        nextError || "Showing the last live version while we wait for another refresh."
      )
    } else {
      this.hideBanner()
    }

    if (!nextWorkingAvailable) {
      this.showLoading(nextStatus, nextError)
    } else if (this.blockingLoad === false) {
      this.hideLoading()
    }

    if (nextWorkingAvailable && nextViewerPath && nextViewerToken && nextViewerToken !== this.currentViewerToken) {
      this.currentViewerToken = nextViewerToken
      this.loadFrame(nextViewerPath, { blocking: !previousWorkingAvailable })
    }
  }

  loadFrame(url, { blocking }) {
    if (!this.hasFrameTarget) return

    this.blockingLoad = blocking
    this.loaded = false

    if (blocking) {
      this.showLoading("missing", null)
    } else {
      this.element.classList.add("is-loaded")
      this.element.classList.remove("is-loading")
    }

    this.frameTarget.setAttribute("aria-busy", "true")
    this.frameTarget.src = url
  }

  showLoading(status, errorMessage) {
    if (!this.hasLoadingTarget) return

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = status === "failed" ? "Unable to prepare live PDF." : "Preparing live PDF..."
    }

    if (this.hasDetailTarget) {
      if (status === "failed") {
        this.detailTarget.textContent = errorMessage || "Try again in a moment."
      } else {
        this.detailTarget.textContent = "This packet is building its live preview. It will appear automatically as soon as the working PDF is ready."
      }
    }

    this.clearTimers()
    this.loadingTarget.hidden = false
    this.element.classList.add("is-loading")
    this.element.classList.remove("is-loaded")

    if (status !== "failed") {
      this.slowTimer = window.setTimeout(() => this.showSlowState(), 1800)
      this.stillRenderingTimer = window.setTimeout(() => this.showStillRenderingState(), 7000)
    }
  }

  hideLoading() {
    if (!this.hasLoadingTarget) return

    this.clearTimers()
    this.loadingTarget.hidden = true
    this.element.classList.remove("is-loading")
    this.element.classList.add("is-loaded")
  }

  showBanner(message, detail) {
    if (!this.hasBannerTarget) return

    this.bannerTarget.hidden = false
    if (this.hasBannerMessageTarget) this.bannerMessageTarget.textContent = message
    if (this.hasBannerDetailTarget) this.bannerDetailTarget.textContent = detail
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = true
  }

  showSlowState() {
    if (this.loaded || !this.hasLoadingTarget || this.loadingTarget.hidden) return
    if (this.hasMessageTarget) this.messageTarget.textContent = "Rendering live PDF..."
    if (this.hasDetailTarget) {
      this.detailTarget.textContent = "The first preview, or a freshly updated packet, can take a few seconds to build."
    }
  }

  showStillRenderingState() {
    if (this.loaded || !this.hasLoadingTarget || this.loadingTarget.hidden) return
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
