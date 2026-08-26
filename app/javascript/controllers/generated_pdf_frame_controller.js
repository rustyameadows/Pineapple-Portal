import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["shell", "frame", "loading", "message", "detail", "banner", "bannerMessage", "bannerDetail", "pill", "pillTime", "hint"]
  static values = {
    statusUrl: String,
    initialStatus: String,
    initialWorkingAvailable: Boolean,
    initialViewerToken: String,
    initialRefreshError: String,
    initialProgressMessage: String
  }

  connect() {
    this.loaded = false
    this.currentStatus = this.initialStatusValue || "missing"
    this.currentViewerToken = this.initialViewerTokenValue || null
    this.workingAvailable = this.initialWorkingAvailableValue
    this.blockingLoad = !this.workingAvailable
    this.clearBannerOnFrameLoad = false
    this.pendingReadyViewerToken = null

    if (this.hasFrameTarget && this.workingAvailable) this.frameTarget.setAttribute("aria-busy", "true")
    this.applyStatus({
      status: this.currentStatus,
      working_available: this.workingAvailable,
      viewer_token: this.currentViewerToken,
      refresh_error: this.initialRefreshErrorValue,
      progress_message: this.initialProgressMessageValue
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
    if (this.clearBannerOnFrameLoad && this.workingAvailable) {
      this.hideBanner()
      this.clearBannerOnFrameLoad = false
    }
    if (this.hasFrameTarget) this.frameTarget.removeAttribute("aria-busy")
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
    const nextRenderedAt = data.rendered_at || null
    const nextProgressMessage = data.progress_message || null
    const retrying = !!(nextProgressMessage && nextProgressMessage.startsWith("Retrying live PDF"))
    const viewerTokenChanged = !!(nextWorkingAvailable && nextViewerToken && nextViewerToken !== this.currentViewerToken)

    this.currentStatus = nextStatus
    this.workingAvailable = nextWorkingAvailable
    this.currentProgressMessage = nextProgressMessage
    this.updateLivePill(nextRenderedAt)
    const activeBuild = nextStatus === "pending" || nextStatus === "running"

    if (viewerTokenChanged) {
      this.pendingReadyViewerToken = nextViewerToken
      this.hideBanner()
    } else if (nextStatus === "failed" && nextWorkingAvailable) {
      this.showBanner(
        "Live PDF refresh failed.",
        nextError || "Showing the last live version while we wait for another refresh."
      )
    } else if (nextStatus === "failed") {
      this.showBanner(
        "Unable to prepare live PDF.",
        nextError || "Try again in a moment."
      )
    } else if (activeBuild && nextWorkingAvailable) {
      if (this.pendingReadyViewerToken && nextViewerToken === this.pendingReadyViewerToken) {
        this.hideBanner()
      } else {
        this.showBanner(
          "A newer live PDF is being prepared.",
          retrying
            ? "Showing the last live version while we retry the render automatically."
            : "Showing the last live version until the refreshed packet is ready."
        )
      }
    } else if (activeBuild) {
      this.showBanner(
        retrying ? "Retrying live PDF after a stalled render" : (nextRenderedAt ? "Refreshing live PDF..." : "Preparing live PDF..."),
        retrying
          ? "The last live render stalled, so we started a fresh retry automatically."
          : nextRenderedAt
          ? "We’re rebuilding the working preview with the latest packet content."
          : "This packet is building its live preview. It will appear here automatically."
      )
    } else if (!nextWorkingAvailable) {
      this.pendingReadyViewerToken = null
      this.showBanner(
        nextRenderedAt ? "Refreshing live PDF..." : "Preparing live PDF...",
        nextRenderedAt
          ? "We’re rebuilding the working preview with the latest packet content."
          : "This packet is building its live preview. It will appear here automatically."
      )
    } else {
      this.pendingReadyViewerToken = null
      this.hideBanner()
    }

    if (!nextWorkingAvailable) {
      this.showLoading(nextStatus, nextError, nextProgressMessage, retrying)
    } else if (this.blockingLoad === false) {
      this.hideLoading()
    }

    if (viewerTokenChanged && nextViewerPath) {
      this.hideBanner()
      this.currentViewerToken = nextViewerToken
      this.loadFrame(nextViewerPath, { blocking: !previousWorkingAvailable })
    }
  }

  loadFrame(url, { blocking }) {
    if (!this.hasFrameTarget) return

    this.blockingLoad = blocking
    this.loaded = false
    this.clearBannerOnFrameLoad = true
    const shell = this.shellElement()

    if (blocking) {
      this.showLoading("missing", null, this.currentProgressMessage)
    } else {
      shell.classList.add("is-loaded")
      shell.classList.remove("is-loading")
    }

    this.frameTarget.setAttribute("aria-busy", "true")
    this.frameTarget.src = url
  }

  showLoading(status, errorMessage, progressMessage = null, retrying = false) {
    if (!this.hasLoadingTarget) return

    if (this.hasMessageTarget) {
      this.messageTarget.textContent = progressMessage || (status === "failed" ? "Unable to prepare live PDF." : "Preparing live PDF...")
    }

    if (this.hasDetailTarget) {
      if (status === "failed") {
        this.detailTarget.textContent = errorMessage || "Try again in a moment."
      } else if (retrying) {
        this.detailTarget.textContent = "The last live render stalled, so we started a fresh retry automatically."
      } else {
        this.detailTarget.textContent = "This packet is building its live preview. It will appear automatically as soon as the working PDF is ready."
      }
    }

    this.clearTimers()
    this.loadingTarget.hidden = false
    const shell = this.shellElement()
    shell.classList.add("is-loading")
    shell.classList.remove("is-loaded")

    if (status !== "failed") {
      this.slowTimer = window.setTimeout(() => this.showSlowState(), 1800)
      this.stillRenderingTimer = window.setTimeout(() => this.showStillRenderingState(), 7000)
    }
  }

  hideLoading() {
    if (!this.hasLoadingTarget) return

    this.clearTimers()
    this.loadingTarget.hidden = true
    const shell = this.shellElement()
    shell.classList.remove("is-loading")
    shell.classList.add("is-loaded")
  }

  showBanner(message, detail) {
    if (!this.hasBannerTarget) return

    this.bannerTarget.hidden = false
    if (this.hasBannerMessageTarget) this.bannerMessageTarget.textContent = this.currentProgressMessage || message
    if (this.hasBannerDetailTarget) this.bannerDetailTarget.textContent = detail
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = true
  }

  updateLivePill(iso) {
    if (!this.hasPillTarget || !this.hasPillTimeTarget) return

    if (!iso) {
      this.pillTarget.hidden = true
      if (this.hasHintTarget) this.hintTarget.hidden = false
      return
    }

    this.pillTarget.hidden = false
    if (this.hasHintTarget) this.hintTarget.hidden = true

    this.pillTimeTarget.dataset.localTimeIsoValue = iso
    this.pillTimeTarget.setAttribute("datetime", iso)
    this.pillTimeTarget.textContent = this.formatTimestamp(iso)
  }

  shellElement() {
    return this.hasShellTarget ? this.shellTarget : this.element
  }

  formatTimestamp(iso) {
    const date = new Date(iso)
    if (Number.isNaN(date.getTime())) return ""

    return new Intl.DateTimeFormat(undefined, {
      month: "short",
      day: "2-digit",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit"
    }).format(date)
  }

  showSlowState() {
    if (this.loaded || !this.hasLoadingTarget || this.loadingTarget.hidden) return
    if (this.currentProgressMessage) return
    if (this.hasMessageTarget) this.messageTarget.textContent = "Rendering live PDF..."
    if (this.hasDetailTarget) {
      this.detailTarget.textContent = "The first preview, or a freshly updated packet, can take a few seconds to build."
    }
  }

  showStillRenderingState() {
    if (this.loaded || !this.hasLoadingTarget || this.loadingTarget.hidden) return
    if (this.currentProgressMessage) return
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
