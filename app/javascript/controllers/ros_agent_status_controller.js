import { Controller } from "@hotwired/stimulus"

const ACTIVE_STATUSES = new Set(["draft", "analyzing", "drafting", "planning", "applying"])
const ACTION_ANCHORS = {
  needs_input: "planning-questions",
  ready_for_review: "review-plan"
}

export default class extends Controller {
  static targets = ["statusLabel", "statusSummary", "sourceFiles", "llmCalls", "latestError", "taskHistory"]
  static values = {
    statusUrl: String,
    initialStatus: String,
    initialActionAnchor: String
  }

  connect() {
    this.currentStatus = this.initialStatusValue || ""
    this.currentActionAnchor = this.initialActionAnchorValue || this.actionAnchorForStatus(this.currentStatus)
    this.revealActionForAnchor(this.currentActionAnchor, { reloadIfMissing: false })
    if (!this.shouldPoll(this.currentStatus)) return

    this.pollTimer = window.setInterval(() => this.pollStatus(), 2000)
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

      this.applyStatus(await response.json())
    } catch (_error) {
      // Leave the existing content alone when polling fails.
    }
  }

  applyStatus(data) {
    const previousStatus = this.currentStatus
    const previousActionAnchor = this.currentActionAnchor
    const nextStatus = data.status || this.currentStatus
    const nextActionAnchor = data.action_anchor || this.actionAnchorForStatus(nextStatus)
    const active = data.active == null ? this.shouldPoll(nextStatus) : Boolean(data.active)
    this.currentStatus = nextStatus
    this.currentActionAnchor = nextActionAnchor

    this.updateStatusLabel(nextStatus, data.status_label)
    this.updateStatusSummary(nextStatus, active, data.status_label)
    this.updateTarget("sourceFiles", this.renderSourceFiles(data.source_files))
    this.updateTarget("llmCalls", this.renderLlmCalls(data.llm_calls))
    this.updateTarget("latestError", this.renderLatestError(data.last_error))
    this.updateTarget("taskHistory", this.renderTaskHistory(data.task_events))

    if (!active) {
      window.clearInterval(this.pollTimer)
    }

    if (nextActionAnchor && (nextStatus !== previousStatus || nextActionAnchor !== previousActionAnchor)) {
      this.revealActionForAnchor(nextActionAnchor, { reloadIfMissing: true })
    }
  }

  shouldPoll(status) {
    return ACTIVE_STATUSES.has(status)
  }

  updateStatusLabel(status, label) {
    if (!this.hasStatusLabelTarget) return

    this.statusLabelTarget.textContent = label || this.humanizeStatus(status)
    this.statusLabelTarget.className = `event-approvals__status-pill event-approvals__status-pill--${status || "draft"}`
  }

  updateStatusSummary(status, active, label) {
    if (!this.hasStatusSummaryTarget) return

    const inactiveLabel = (label || this.humanizeStatus(status)).toLowerCase()
    this.statusSummaryTarget.textContent = active
      ? "Polling every 2 seconds while the task is active."
      : `Polling stopped for ${inactiveLabel || "this task"}.`
  }

  updateTarget(targetName, html) {
    const target = this[`has${targetName.charAt(0).toUpperCase()}${targetName.slice(1)}Target`] ? this[`${targetName}Target`] : null
    if (!target) return
    target.innerHTML = html
  }

  actionAnchorForStatus(status) {
    return ACTION_ANCHORS[status] || null
  }

  revealActionForAnchor(anchorId, { reloadIfMissing }) {
    if (!anchorId) return

    const target = document.getElementById(anchorId)
    if (target) {
      this.scrollToTarget(target, anchorId)
      return
    }

    if (reloadIfMissing) {
      window.location.assign(this.urlWithHash(anchorId))
    }
  }

  scrollToTarget(target, anchorId) {
    if (window.location.hash !== `#${anchorId}`) {
      window.history.replaceState(null, "", this.urlWithHash(anchorId))
    }

    target.scrollIntoView({ block: "start", behavior: "smooth" })
    target.focus({ preventScroll: true })
  }

  urlWithHash(anchorId) {
    return `${window.location.pathname}${window.location.search}#${anchorId}`
  }

  renderSourceFiles(sourceFiles = []) {
    if (!Array.isArray(sourceFiles) || sourceFiles.length === 0) {
      return '<p class="event-section__empty">No source files yet.</p>'
    }

    return `
      <table class="event-table">
        <thead>
          <tr>
            <th>File</th>
            <th>Size</th>
            <th>OpenAI File</th>
          </tr>
        </thead>
        <tbody>
          ${sourceFiles.map((sourceFile) => `
            <tr>
              <td>${this.escapeHtml(sourceFile.filename)}</td>
              <td>${this.escapeHtml(sourceFile.size_label || this.formatBytes(sourceFile.size_bytes))}</td>
              <td>${this.escapeHtml(sourceFile.openai_file_id || this.humanizeStatus(sourceFile.openai_state))}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    `
  }

  renderLlmCalls(llmCalls = []) {
    if (!Array.isArray(llmCalls) || llmCalls.length === 0) {
      return '<p class="event-section__empty">No OpenAI calls yet.</p>'
    }

    return `
      <table class="event-table">
        <thead>
          <tr>
            <th>Purpose</th>
            <th>Status</th>
            <th>Model</th>
            <th>Duration</th>
            <th>Usage</th>
            <th>Error</th>
          </tr>
        </thead>
        <tbody>
          ${llmCalls.map((call) => {
            const usage = call.usage || {}
            const error = call.error || {}
            return `
              <tr>
                <td>${this.escapeHtml(this.humanizeStatus(call.purpose))}</td>
                <td>${this.escapeHtml(this.humanizeStatus(call.status))}</td>
                <td>${this.escapeHtml(call.model)}</td>
                <td>${this.escapeHtml(call.duration_label || this.formatDuration(call.duration_ms))}</td>
                <td>${this.escapeHtml(this.formatJson(usage))}</td>
                <td>${this.escapeHtml(error.message || "—")}</td>
              </tr>
            `
          }).join("")}
        </tbody>
      </table>
    `
  }

  renderLatestError(lastError) {
    if (!lastError) {
      return '<p class="event-section__empty">No task error recorded yet.</p>'
    }

    const errorClass = lastError.class || "Error"
    const message = lastError.message || "Unknown error"
    return `<p><strong>${this.escapeHtml(errorClass)}:</strong> ${this.escapeHtml(message)}</p>`
  }

  renderTaskHistory(taskEvents = []) {
    if (!Array.isArray(taskEvents) || taskEvents.length === 0) {
      return '<p class="event-section__empty">No task history yet.</p>'
    }

    return `
      <table class="event-table">
        <thead>
          <tr>
            <th>Event</th>
            <th>Message</th>
            <th>When</th>
            <th>By</th>
          </tr>
        </thead>
        <tbody>
          ${taskEvents.map((event) => `
            <tr>
              <td>${this.escapeHtml(this.humanizeStatus(event.event_type))}</td>
              <td>${this.escapeHtml(event.message || "—")}</td>
              <td>${this.escapeHtml(event.created_at_label || event.created_at || "—")}</td>
              <td>${this.escapeHtml(event.created_by || "—")}</td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    `
  }

  formatBytes(bytes) {
    if (bytes == null || bytes === "") return "—"

    const value = Number(bytes)
    if (Number.isNaN(value)) return this.escapeHtml(String(bytes))

    const units = ["B", "KB", "MB", "GB", "TB"]
    let size = value
    let unitIndex = 0

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024
      unitIndex += 1
    }

    const rounded = size >= 10 || unitIndex === 0 ? Math.round(size) : size.toFixed(1)
    return `${rounded} ${units[unitIndex]}`
  }

  formatDuration(durationMs) {
    if (durationMs == null || durationMs === "") return "—"
    return `${durationMs} ms`
  }

  formatJson(value) {
    if (!value || (typeof value === "object" && Object.keys(value).length === 0)) return "—"
    return JSON.stringify(value)
  }

  humanizeStatus(status) {
    if (!status) return ""

    return status
      .toString()
      .split("_")
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ")
  }

  escapeHtml(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }
}
