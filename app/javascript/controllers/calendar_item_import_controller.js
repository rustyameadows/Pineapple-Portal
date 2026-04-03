import { Controller } from "@hotwired/stimulus"

const DAY_IN_MS = 24 * 60 * 60 * 1000

export default class extends Controller {
  static targets = [
    "anchorDateInput",
    "anchorHelp",
    "anchorLabel",
    "batchTagCheckbox",
    "batchTagLabel",
    "batchTagMeta",
    "dialog",
    "dialogEmpty",
    "dialogTable",
    "fallbackCount",
    "form",
    "itemCheckbox",
    "missingCount",
    "previewContent",
    "previewEmpty",
    "previewTable",
    "reviewButton",
    "selectAllButton",
    "deselectAllButton",
    "selectionCount",
    "selectionHint",
    "selectionModeInput"
  ]

  static values = {
    anchorRequired: Boolean,
    destinationTagNames: Array,
    destinationTimezone: String,
    destinationTimezoneLabel: String,
    expectedBatchTagName: String,
    items: Array,
    sourceEventStart: String
  }

  connect() {
    this.sortedItems = [...this.itemsValue].sort((left, right) => {
      const leftPosition = Number(left.position || 0)
      const rightPosition = Number(right.position || 0)
      if (leftPosition !== rightPosition) return leftPosition - rightPosition
      return Number(left.id) - Number(right.id)
    })

    this.render()
  }

  controlsChanged() {
    this.render()
  }

  selectionChanged() {
    this.render()
  }

  selectAll() {
    this.setSelectionMode("selected")
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = true
    })
    this.render()
  }

  deselectAll() {
    this.setSelectionMode("selected")
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })
    this.render()
  }

  openDialog(event) {
    event.preventDefault()

    const projection = this.currentProjection
    if (!projection.readyToConfirm) {
      if (projection.reason === "anchor" && this.hasAnchorDateInputTarget) this.anchorDateInputTarget.focus()
      return
    }

    this.dialogEmptyTarget.hidden = true
    this.dialogEmptyTarget.textContent = ""
    this.dialogTableTarget.innerHTML = this.renderTableHTML(projection.groups)

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  closeDialog() {
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  submitConfirmed() {
    this.closeDialog()
    this.formTarget.requestSubmit()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.closeDialog()
  }

  render() {
    this.syncSelectionModeState()

    const projection = this.buildProjection()
    this.currentProjection = projection

    this.selectionCountTargets.forEach((target) => {
      target.textContent = String(projection.selectedCount)
    })
    this.fallbackCountTargets.forEach((target) => {
      target.textContent = String(projection.fallbackCount)
    })
    this.missingCountTargets.forEach((target) => {
      target.textContent = String(projection.missingCount)
    })
    this.anchorLabelTargets.forEach((target) => {
      target.textContent = projection.anchorLabel
    })
    this.batchTagLabelTargets.forEach((target) => {
      target.textContent = projection.batchTagLabel
    })
    this.batchTagMetaTargets.forEach((target) => {
      target.textContent = projection.batchTagLabel
    })

    if (this.hasSelectionHintTarget) {
      this.selectionHintTarget.textContent = projection.selectionHint
    }

    if (this.hasAnchorHelpTarget && projection.anchorMessage) {
      this.anchorHelpTarget.textContent = projection.anchorMessage
    }

    if (this.hasReviewButtonTarget) {
      this.reviewButtonTarget.disabled = !projection.readyToConfirm
    }

    if (projection.readyToConfirm) {
      this.previewContentTarget.hidden = false
      this.previewEmptyTarget.hidden = true
      this.previewEmptyTarget.textContent = ""
      this.previewTableTarget.innerHTML = this.renderTableHTML(projection.groups)
    } else {
      this.previewContentTarget.hidden = true
      this.previewTableTarget.innerHTML = ""
      this.previewEmptyTarget.hidden = false
      this.previewEmptyTarget.textContent = projection.emptyMessage
      if (this.dialogOpen) this.closeDialog()
    }
  }

  syncSelectionModeState() {
    const allMode = this.selectionMode === "all"
    this.itemCheckboxTargets.forEach((checkbox) => {
      checkbox.disabled = allMode
    })

    const checkedCount = this.itemCheckboxTargets.filter((checkbox) => checkbox.checked).length
    const totalCount = this.itemCheckboxTargets.length

    if (this.hasSelectAllButtonTarget) {
      this.selectAllButtonTarget.disabled = totalCount === 0 || (checkedCount === totalCount && !allMode)
    }

    if (this.hasDeselectAllButtonTarget) {
      this.deselectAllButtonTarget.disabled = totalCount === 0 || checkedCount === 0
    }
  }

  buildProjection() {
    const selectedItems = this.selectedItems
    const selectedCount = selectedItems.length
    const sourceHasAnchor = this.sourceEventStartValue.length > 0
    const anchorDateValue = this.hasAnchorDateInputTarget ? this.anchorDateInputTarget.value : ""
    const batchTagEnabled = this.hasBatchTagCheckboxTarget && this.batchTagCheckboxTarget.checked
    const batchTagLabel = batchTagEnabled ? this.computeNextBatchTagName() : "Not added"

    const anchorMessage = sourceHasAnchor
      ? "Source times will be shifted from the source event start date onto the chosen anchor date."
      : "This source event does not have a start date, so scheduled items will keep their original dates and times."

    const selectionHint = this.selectionMode === "all"
      ? `All ${this.itemsValue.length} listed item${this.itemsValue.length === 1 ? "" : "s"} will be imported.`
      : "Only checked rows will be imported."

    if (selectedCount === 0) {
      return {
        anchorLabel: anchorDateValue ? this.formatDateOnly(anchorDateValue) : "Not set",
        anchorMessage,
        batchTagLabel,
        emptyMessage: "Select items to preview the projected import schedule.",
        fallbackCount: 0,
        groups: [],
        missingCount: 0,
        readyToConfirm: false,
        reason: "selection",
        selectedCount: 0,
        selectionHint
      }
    }

    if (this.anchorRequiredValue && !anchorDateValue) {
      return {
        anchorLabel: "Not set",
        anchorMessage: "Choose an anchor date before previewing or importing this batch.",
        batchTagLabel,
        emptyMessage: "Choose an anchor date to preview the projected import schedule.",
        fallbackCount: 0,
        groups: [],
        missingCount: 0,
        readyToConfirm: false,
        reason: "anchor",
        selectedCount,
        selectionHint
      }
    }

    const shiftDays = sourceHasAnchor && anchorDateValue
      ? this.dayDifference(anchorDateValue, this.sourceEventStartValue)
      : 0

    const selectedIds = new Set(selectedItems.map((item) => Number(item.id)))
    const plansById = new Map()
    const plans = []
    let fallbackCount = 0
    let missingCount = 0

    selectedItems.forEach((item) => {
      const relativeAnchorId = Number(item.relative_anchor_id || 0)
      const preservesRelative = relativeAnchorId > 0 && selectedIds.has(relativeAnchorId)
      let projectedStart = null
      let projectedEnd = null
      let status = ""

      if (preservesRelative) {
        const anchorPlan = plansById.get(relativeAnchorId)
        projectedStart = this.projectRelativeStart(item, anchorPlan)
        projectedEnd = this.projectedEnd(item, projectedStart)
        status = projectedStart ? "Relative link preserved" : "Relative link preserved • time TBD"
      } else if (relativeAnchorId > 0) {
        projectedStart = this.shiftIso(item.source_effective_start, shiftDays)
        projectedEnd = this.shiftIso(item.source_effective_end, shiftDays) || this.projectedEnd(item, projectedStart)
        fallbackCount += 1
        if (projectedStart) {
          status = "Will convert to absolute time"
        } else {
          status = "No computable start time"
          missingCount += 1
        }
      } else {
        projectedStart = this.shiftIso(item.source_starts_at, shiftDays)
        projectedEnd = this.shiftIso(item.source_effective_end, shiftDays) || this.projectedEnd(item, projectedStart)
        status = projectedStart ? "Absolute time retained" : "No computable start time"
      }

      const plan = {
        id: Number(item.id),
        itemTitle: item.title,
        sourceLabel: this.formatRange(item.source_effective_start, item.source_effective_end),
        sourceCaption: item.time_caption || "",
        projectedLabel: this.formatRange(projectedStart, projectedEnd),
        projectedCaption: item.time_caption || "",
        projectedStart,
        status
      }

      plansById.set(plan.id, plan)
      plans.push(plan)
    })

    return {
      anchorLabel: anchorDateValue ? this.formatDateOnly(anchorDateValue) : "Not set",
      anchorMessage,
      batchTagLabel,
      emptyMessage: "",
      fallbackCount,
      groups: this.groupPlans(plans),
      missingCount,
      readyToConfirm: true,
      reason: null,
      selectedCount,
      selectionHint
    }
  }

  groupPlans(plans) {
    const groups = []
    const groupsByKey = new Map()

    plans.forEach((plan) => {
      const key = plan.projectedStart ? this.dateKey(plan.projectedStart) : "date-tbd"
      if (!groupsByKey.has(key)) {
        const group = {
          key,
          label: plan.projectedStart ? this.formatGroupLabel(plan.projectedStart) : "Date TBD",
          rows: []
        }
        groupsByKey.set(key, group)
        groups.push(group)
      }

      groupsByKey.get(key).rows.push(plan)
    })

    return groups
  }

  renderTableHTML(groups) {
    const body = groups.map((group) => {
      const rows = group.rows.map((plan) => {
        const sourceCaption = plan.sourceCaption ? `<div class="event-calendars__import-cell-meta">${this.escapeHtml(plan.sourceCaption)}</div>` : ""
        const projectedCaption = plan.projectedCaption ? `<div class="event-calendars__import-cell-meta">${this.escapeHtml(plan.projectedCaption)}</div>` : ""

        return `
          <tr class="event-calendars__row">
            <td class="event-calendars__title-column">
              <strong class="event-calendars__import-item-title">${this.escapeHtml(plan.itemTitle)}</strong>
            </td>
            <td>
              <div>${this.escapeHtml(plan.sourceLabel)}</div>
              ${sourceCaption}
            </td>
            <td>
              <div>${this.escapeHtml(plan.projectedLabel)}</div>
              ${projectedCaption}
            </td>
            <td>${this.escapeHtml(plan.status)}</td>
          </tr>
        `
      }).join("")

      return `
        <tr class="event-calendars__date-row">
          <td colspan="4"><span class="event-calendars__date-label">${this.escapeHtml(group.label)}</span></td>
        </tr>
        ${rows}
      `
    }).join("")

    return `
      <table class="event-table event-calendars__table event-calendars__import-preview-table">
        <thead>
          <tr>
            <th class="event-calendars__title-column">Item</th>
            <th>Source</th>
            <th>Imported</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>${body}</tbody>
      </table>
    `
  }

  projectRelativeStart(item, anchorPlan) {
    if (!anchorPlan || !anchorPlan.projectedStart) return null

    let baseTime = anchorPlan.projectedStart
    if (item.relative_to_anchor_end) {
      baseTime = anchorPlan.projectedEnd || anchorPlan.projectedStart
    }
    if (!baseTime) return null

    const offsetMinutes = Number(item.relative_offset_minutes || 0)
    const signedOffset = item.relative_before ? -offsetMinutes : offsetMinutes
    return new Date(new Date(baseTime).getTime() + (signedOffset * 60 * 1000)).toISOString()
  }

  projectedEnd(item, projectedStart) {
    if (!projectedStart || item.duration_minutes == null || item.duration_minutes === "") return null

    const durationMinutes = Number(item.duration_minutes || 0)
    return new Date(new Date(projectedStart).getTime() + (durationMinutes * 60 * 1000)).toISOString()
  }

  shiftIso(value, shiftDays) {
    if (!value) return null

    return new Date(new Date(value).getTime() + (shiftDays * DAY_IN_MS)).toISOString()
  }

  computeNextBatchTagName() {
    const suffixes = this.destinationTagNamesValue
      .map((name) => String(name || "").trim())
      .map((name) => name.match(/^imported(?:-(\d+))?$/i))
      .filter(Boolean)
      .map((match) => (match[1] ? Number(match[1]) : 1))

    if (suffixes.length === 0) return this.expectedBatchTagNameValue || "imported"

    return `imported-${Math.max(...suffixes) + 1}`
  }

  dayDifference(anchorDateValue, sourceDateValue) {
    const anchorDate = this.parseDateOnly(anchorDateValue)
    const sourceDate = this.parseDateOnly(sourceDateValue)
    if (!anchorDate || !sourceDate) return 0

    return Math.round((anchorDate.getTime() - sourceDate.getTime()) / DAY_IN_MS)
  }

  parseDateOnly(value) {
    if (!value) return null

    const parts = String(value).split("-").map((token) => Number(token))
    if (parts.length !== 3 || parts.some((token) => Number.isNaN(token))) return null

    return new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]))
  }

  formatDateOnly(value) {
    const date = this.parseDateOnly(value)
    if (!date) return "Not set"

    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
      timeZone: "UTC"
    }).format(date)
  }

  formatGroupLabel(isoValue) {
    return new Intl.DateTimeFormat("en-US", {
      weekday: "long",
      month: "long",
      day: "numeric",
      timeZone: this.destinationTimezoneValue
    }).format(new Date(isoValue))
  }

  dateKey(isoValue) {
    return new Intl.DateTimeFormat("en-CA", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      timeZone: this.destinationTimezoneValue
    }).format(new Date(isoValue))
  }

  formatRange(startIso, endIso) {
    if (!startIso) return "Time TBD"

    const start = new Date(startIso)
    const startLabel = this.formatDateTime(start)

    if (!endIso) return startLabel

    const end = new Date(endIso)
    const sameDay = this.dateKey(startIso) === this.dateKey(endIso)
    const endLabel = sameDay ? this.formatTimeOnly(end) : this.formatDateTime(end)

    return `${startLabel} – ${endLabel}`
  }

  formatDateTime(date) {
    if (this.isMidnight(date)) return this.formatMonthDay(date)

    return `${this.formatMonthDay(date)} • ${this.formatTimeOnly(date)}`
  }

  formatMonthDay(date) {
    return new Intl.DateTimeFormat("en-US", {
      month: "short",
      day: "numeric",
      timeZone: this.destinationTimezoneValue
    }).format(date)
  }

  formatTimeOnly(date) {
    return new Intl.DateTimeFormat("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
      timeZone: this.destinationTimezoneValue
    }).format(date)
  }

  isMidnight(date) {
    return new Intl.DateTimeFormat("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
      timeZone: this.destinationTimezoneValue
    }).format(date) === "00:00"
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll("\"", "&quot;")
      .replaceAll("'", "&#39;")
  }

  get selectionMode() {
    const selected = this.selectionModeInputTargets.find((input) => input.checked)
    return selected ? selected.value : "selected"
  }

  get selectedItems() {
    if (this.selectionMode === "all") return this.sortedItems

    const selectedIds = new Set(
      this.itemCheckboxTargets
        .filter((checkbox) => checkbox.checked)
        .map((checkbox) => Number(checkbox.value))
    )

    return this.sortedItems.filter((item) => selectedIds.has(Number(item.id)))
  }

  get dialogOpen() {
    if (!this.hasDialogTarget) return false
    if ("open" in this.dialogTarget) return this.dialogTarget.open

    return this.dialogTarget.hasAttribute("open")
  }

  setSelectionMode(value) {
    const input = this.selectionModeInputTargets.find((target) => target.value === value)
    if (input) input.checked = true
  }
}
