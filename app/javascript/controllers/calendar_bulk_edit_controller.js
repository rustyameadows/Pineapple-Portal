import { Controller } from "@hotwired/stimulus"

const FACETS = ["vendor", "location", "team", "tag"]
const FACET_PARAMS = {
  vendor: "vendors[]",
  location: "locations[]",
  team: "teams[]",
  tag: "tags[]"
}

export default class extends Controller {
  static highlightName = "calendar-bulk-edit-search-match"
  static targets = [
    "actionLabel",
    "actionSelect",
    "additionalTeamMembersRow",
    "absoluteTimingButton",
    "absoluteTimingFields",
    "absoluteTimingSummary",
    "applyButton",
    "checkbox",
    "clearFiltersButton",
    "dialog",
    "facetSummary",
    "filterCheckbox",
    "filterDropdown",
    "filteredEmpty",
    "form",
    "groupRow",
    "locationRow",
    "panel",
    "returnLink",
    "returnToInput",
    "relativeAnchorPointSelect",
    "relativeAnchorSelect",
    "relativeTargetSelect",
    "relativeTimingButton",
    "relativeTimingDialog",
    "relativeTimingFields",
    "relativeTimingForm",
    "relativeTimingSummary",
    "row",
    "searchableText",
    "searchInput",
    "selectionCount",
    "tableShell",
    "tagsRow",
    "teamMembersRow",
    "timeLabelRow",
    "timingAnchorInput",
    "timingAnchorPointInput",
    "timingDialogCopy",
    "timingDialogTitle",
    "timingModeInput",
    "timingReturnToInput",
    "timingSubmitButton",
    "timingTargetInput",
    "vendorRow",
    "visibleSelectionButton"
  ]

  connect() {
    this.rowStates = this.rowTargets.map((row) => ({
      element: row,
      checkbox: row.querySelector("input.event-calendars__bulk-checkbox"),
      groupKey: row.dataset.calendarGroupKey || "",
      searchText: row.dataset.calendarSearchText || "",
      filters: {
        vendor: this.parseFilterValues(row.dataset.calendarVendorValues),
        location: this.parseFilterValues(row.dataset.calendarLocationValues),
        team: this.parseFilterValues(row.dataset.calendarTeamValues),
        tag: this.parseFilterValues(row.dataset.calendarTagValues)
      }
    }))

    if (!this.hasSearchInputTarget && !this.hasFilterCheckboxTarget) {
      this.updateSelectionState()
      this.updateActionState()
      return
    }

    this.boundCloseFilterDropdownsOnOutsideClick = this.closeFilterDropdownsOnOutsideClick.bind(this)
    this.boundCloseFilterDropdownsOnEscape = this.closeFilterDropdownsOnEscape.bind(this)
    document.addEventListener("click", this.boundCloseFilterDropdownsOnOutsideClick, true)
    document.addEventListener("keydown", this.boundCloseFilterDropdownsOnEscape)

    this.applyFiltersFromUrl()
    this.updateSelectionState()
    this.updateActionState()
    this.applyFilters()
  }

  disconnect() {
    if (this.boundCloseFilterDropdownsOnOutsideClick) {
      document.removeEventListener("click", this.boundCloseFilterDropdownsOnOutsideClick, true)
    }
    if (this.boundCloseFilterDropdownsOnEscape) {
      document.removeEventListener("keydown", this.boundCloseFilterDropdownsOnEscape)
    }
    this.clearHighlights()
  }

  selectionChanged() {
    this.updateSelectionState()
  }

  actionChanged() {
    this.updateActionState()
  }

  filtersChanged() {
    this.applyFilters()
  }

  dropdownToggled(event) {
    if (!event.currentTarget.open) return

    this.filterDropdownTargets.forEach((dropdown) => {
      if (dropdown !== event.currentTarget) dropdown.open = false
    })
  }

  toggleVisibleSelection() {
    const visibleCheckboxes = this.visibleCheckboxes
    if (visibleCheckboxes.length === 0) return

    const shouldSelect = !this.allVisibleRowsSelected
    visibleCheckboxes.forEach((checkbox) => {
      checkbox.checked = shouldSelect
    })

    if (!shouldSelect && this.selectedCount === 0) this.closeDialog()
    this.updateSelectionState()
  }

  selectGroup(event) {
    event.preventDefault()
    this.setGroupSelection(event.currentTarget.dataset.groupKey, true)
  }

  deselectGroup(event) {
    event.preventDefault()
    this.setGroupSelection(event.currentTarget.dataset.groupKey, false)
  }

  clearSelection() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })

    this.closeDialog()
    this.closeTimingDialog()
    this.updateSelectionState()
  }

  clearFilters() {
    if (this.hasSearchInputTarget) this.searchInputTarget.value = ""

    this.filterCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })

    this.closeFilterDropdowns()

    this.applyFilters()
  }

  closeFilterDropdownsOnOutsideClick(event) {
    if (this.filterDropdownTargets.some((dropdown) => dropdown.contains(event.target))) return

    this.closeFilterDropdowns()
  }

  closeFilterDropdownsOnEscape(event) {
    if (event.key !== "Escape") return

    this.closeFilterDropdowns()
  }

  closeFilterDropdowns() {
    this.filterDropdownTargets.forEach((dropdown) => {
      dropdown.open = false
    })
  }

  confirm(event) {
    event.preventDefault()
    if (!this.hasSelection || !this.currentAction) return

    this.actionLabelTargets.forEach((element) => {
      element.textContent = this.currentActionLabel.toLowerCase()
    })

    if (this.dialogOpen) return

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
  }

  openRelativeTimingDialog(event) {
    event.preventDefault()

    const items = this.selectedItemData
    if (items.length !== 2) return

    const defaultTarget = this.defaultRelativeTarget(items)
    const defaultAnchor = items.find((item) => item.id !== defaultTarget.id) || items[1]

    this.populateTimingSelect(this.relativeTargetSelectTarget, items, defaultTarget.id)
    this.populateTimingSelect(this.relativeAnchorSelectTarget, items, defaultAnchor.id)
    this.relativeAnchorPointSelectTarget.value = "start"

    this.timingModeInputTarget.value = "relative"
    this.relativeTimingFieldsTarget.hidden = false
    this.absoluteTimingFieldsTarget.hidden = true
    this.timingDialogTitleTarget.textContent = "Change relative timing"
    this.timingDialogCopyTarget.textContent = "Choose which selected item should move, and which selected item should anchor it."
    this.timingSubmitButtonTarget.textContent = "Save timing"

    this.updateRelativeTimingPreview()
    this.showTimingDialog()
  }

  openAbsoluteTimingDialog(event) {
    event.preventDefault()

    const items = this.selectedItemData
    if (items.length !== 1 || !items[0].relative) return

    this.timingModeInputTarget.value = "absolute"
    this.timingTargetInputTarget.value = items[0].id
    this.timingAnchorInputTarget.value = ""
    this.timingAnchorPointInputTarget.value = "start"
    this.relativeTimingFieldsTarget.hidden = true
    this.absoluteTimingFieldsTarget.hidden = false
    this.timingDialogTitleTarget.textContent = "Make absolute"
    this.timingDialogCopyTarget.textContent = "This will keep the item at its current projected time and remove its anchor."
    this.timingSubmitButtonTarget.textContent = "Make absolute"
    this.absoluteTimingSummaryTarget.textContent = this.absoluteTimingSummary(items[0])
    this.timingSubmitButtonTarget.disabled = !items[0].startAt

    this.showTimingDialog()
  }

  timingSelectionChanged() {
    this.ensureDistinctRelativeSelections()
    this.updateRelativeTimingPreview()
  }

  swapRelativeTiming(event) {
    event.preventDefault()

    const targetValue = this.relativeTargetSelectTarget.value
    this.relativeTargetSelectTarget.value = this.relativeAnchorSelectTarget.value
    this.relativeAnchorSelectTarget.value = targetValue
    this.updateRelativeTimingPreview()
  }

  prepareTimingSubmit(event) {
    this.updateReturnArtifacts()

    if (this.timingModeInputTarget.value === "relative") {
      this.updateRelativeTimingPreview()
      if (!this.timingTargetInputTarget.value || !this.timingAnchorInputTarget.value) {
        event.preventDefault()
      }
    }
  }

  closeTimingDialog() {
    if (!this.hasRelativeTimingDialogTarget) return
    if (!this.timingDialogOpen) return

    if (typeof this.relativeTimingDialogTarget.close === "function") {
      this.relativeTimingDialogTarget.close()
    } else {
      this.relativeTimingDialogTarget.removeAttribute("open")
    }
  }

  timingBackdropClose(event) {
    if (event.target === this.relativeTimingDialogTarget) this.closeTimingDialog()
  }

  closeDialog() {
    if (!this.hasDialogTarget) return
    if (!this.dialogOpen) return

    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  prepareSubmit() {
    this.updateReturnArtifacts()
  }

  submitConfirmed() {
    this.closeDialog()
    this.prepareSubmit()
    this.formTarget.requestSubmit()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.closeDialog()
  }

  focusFirstCheckbox(event) {
    event.preventDefault()
    const firstCheckbox = this.checkboxTargets[0]
    if (!firstCheckbox) return

    if (this.hasTableShellTarget) {
      this.tableShellTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }

    window.setTimeout(() => {
      firstCheckbox.focus()
    }, 120)
  }

  updateSelectionState() {
    const count = this.selectedCount
    this.hasSelection = count > 0

    if (this.hasPanelTarget) {
      this.panelTarget.hidden = !this.hasSelection
    }

    this.selectionCountTargets.forEach((element) => {
      element.textContent = String(count)
    })

    if (!this.hasSelection) this.closeDialog()
    if (!this.hasSelection) this.closeTimingDialog()
    this.updateGroupSelectionButtons()
    this.updateVisibleSelectionButtons()
    this.updateTimingActionState()
    this.updateApplyState()
  }

  updateActionState() {
    const action = this.currentAction
    const showTags = action === "add_tags" || action === "remove_tags"
    const showVendor = action === "set_vendor"
    const showLocation = action === "set_location"
    const showTimeLabel = action === "set_time_label"
    const showTeamMembers = action === "add_team_members" || action === "remove_team_members"
    const showAdditionalTeamMembers = action === "set_additional_team_members"

    if (this.hasTagsRowTarget) this.tagsRowTarget.hidden = !showTags
    if (this.hasVendorRowTarget) this.vendorRowTarget.hidden = !showVendor
    if (this.hasLocationRowTarget) this.locationRowTarget.hidden = !showLocation
    if (this.hasTimeLabelRowTarget) this.timeLabelRowTarget.hidden = !showTimeLabel
    if (this.hasTeamMembersRowTarget) this.teamMembersRowTarget.hidden = !showTeamMembers
    if (this.hasAdditionalTeamMembersRowTarget) this.additionalTeamMembersRowTarget.hidden = !showAdditionalTeamMembers

    this.updateApplyState()
  }

  updateApplyState() {
    if (!this.hasApplyButtonTarget) return
    this.applyButtonTarget.disabled = !this.hasSelection || !this.currentAction
  }

  updateTimingActionState() {
    const items = this.selectedItemData

    if (this.hasRelativeTimingButtonTarget) {
      this.relativeTimingButtonTarget.hidden = items.length !== 2
      this.relativeTimingButtonTarget.disabled = items.length !== 2
    }

    if (this.hasAbsoluteTimingButtonTarget) {
      const canMakeAbsolute = items.length === 1 && items[0].relative
      this.absoluteTimingButtonTarget.hidden = !canMakeAbsolute
      this.absoluteTimingButtonTarget.disabled = !canMakeAbsolute
    }
  }

  showTimingDialog() {
    if (this.timingDialogOpen) return

    if (typeof this.relativeTimingDialogTarget.showModal === "function") {
      this.relativeTimingDialogTarget.showModal()
    } else {
      this.relativeTimingDialogTarget.setAttribute("open", "open")
    }
  }

  populateTimingSelect(select, items, selectedId) {
    select.innerHTML = ""

    items.forEach((item) => {
      const option = document.createElement("option")
      option.value = item.id
      option.textContent = item.title
      option.selected = item.id === selectedId
      select.append(option)
    })
  }

  defaultRelativeTarget(items) {
    const relativeItem = items.find((item) => item.relative)
    return relativeItem || items[0]
  }

  ensureDistinctRelativeSelections() {
    if (this.relativeTargetSelectTarget.value !== this.relativeAnchorSelectTarget.value) return

    const nextAnchor = this.selectedItemData.find((item) => item.id !== this.relativeTargetSelectTarget.value)
    if (nextAnchor) this.relativeAnchorSelectTarget.value = nextAnchor.id
  }

  updateRelativeTimingPreview() {
    const target = this.selectedItemById(this.relativeTargetSelectTarget.value)
    const anchor = this.selectedItemById(this.relativeAnchorSelectTarget.value)
    const anchorPoint = this.relativeAnchorPointSelectTarget.value || "start"

    this.timingTargetInputTarget.value = target?.id || ""
    this.timingAnchorInputTarget.value = anchor?.id || ""
    this.timingAnchorPointInputTarget.value = anchorPoint

    const summary = this.relativeTimingSummary(target, anchor, anchorPoint)
    this.relativeTimingSummaryTarget.textContent = summary.text
    this.timingSubmitButtonTarget.disabled = !summary.valid
  }

  relativeTimingSummary(target, anchor, anchorPoint) {
    if (!target || !anchor || target.id === anchor.id) {
      return { valid: false, text: "Choose two different selected items." }
    }

    if (!target.startAt) {
      return { valid: false, text: `${target.title} does not have a scheduled start time.` }
    }

    const baseIso = anchorPoint === "end" ? (anchor.endAt || anchor.startAt) : anchor.startAt
    if (!baseIso) {
      return { valid: false, text: `${anchor.title} does not have a scheduled time.` }
    }

    const targetTime = new Date(target.startAt)
    const anchorTime = new Date(baseIso)
    if (Number.isNaN(targetTime.getTime()) || Number.isNaN(anchorTime.getTime())) {
      return { valid: false, text: "Choose two scheduled items." }
    }

    const signedOffsetMinutes = Math.round((targetTime.getTime() - anchorTime.getTime()) / 60000)
    const offsetMinutes = Math.abs(signedOffsetMinutes)
    const direction = signedOffsetMinutes < 0 ? "before" : "after"
    const anchorPointLabel = anchorPoint === "end" ? "ends" : "starts"
    const projected = this.formatTimingDate(targetTime)
    const projectedSuffix = projected ? ` → ${projected}` : ""

    if (offsetMinutes === 0) {
      return {
        valid: true,
        text: `${target.title} will start when ${anchor.title} ${anchorPointLabel}${projectedSuffix}`
      }
    }

    return {
      valid: true,
      text: `${target.title} will start ${this.formatDuration(offsetMinutes)} ${direction} ${anchor.title} ${anchorPointLabel}${projectedSuffix}`
    }
  }

  absoluteTimingSummary(item) {
    const projected = this.formatTimingDate(item.startAt)
    if (!projected) return `${item.title} does not have a scheduled start time.`

    return `${item.title} will keep its current projected start → ${projected}`
  }

  applyFilters() {
    const query = this.normalizedSearchQuery
    const activeFilters = this.activeFilters
    let visibleCount = 0

    this.rowStates.forEach((rowState) => {
      const matches = this.matchesFilters(rowState, query, activeFilters)
      rowState.element.hidden = !matches
      if (matches) visibleCount += 1
    })

    this.updateGroupRows()

    if (this.hasFilteredEmptyTarget) {
      this.filteredEmptyTarget.hidden = visibleCount > 0
    }

    this.updateHighlights(this.currentHighlightQuery)
    this.updateFacetSummaries()
    this.updateClearFiltersButton()
    this.syncBrowserUrl()
    this.updateReturnArtifacts()
    this.updateVisibleSelectionButtons()
  }

  applyFiltersFromUrl() {
    const params = new URLSearchParams(window.location.search)

    if (this.hasSearchInputTarget) {
      this.searchInputTarget.value = params.get("q") || ""
    }

    this.filterCheckboxTargets.forEach((checkbox) => {
      const param = checkbox.dataset.filterParam
      const selectedValues = params.getAll(param).map((value) => this.tokenizeFilterValue(value))
      checkbox.checked = selectedValues.includes(checkbox.value)
    })
  }

  updateGroupRows() {
    if (!this.hasGroupRowTarget) return

    const visibleGroupKeys = new Set(
      this.visibleRowStates
        .map((rowState) => rowState.groupKey)
        .filter((groupKey) => groupKey.length > 0)
    )

    this.groupRowTargets.forEach((groupRow) => {
      const isVisible = visibleGroupKeys.has(groupRow.dataset.calendarGroupKey || "")
      groupRow.hidden = !isVisible
      groupRow.classList.toggle("event-calendars__date-row--hidden", !isVisible)
    })

    this.updateGroupSelectionButtons()
  }

  updateFacetSummaries() {
    this.facetSummaryTargets.forEach((summary) => {
      const facet = summary.dataset.facetSummary
      const selectedLabels = this.filterCheckboxTargets
        .filter((checkbox) => checkbox.dataset.filterFacet === facet && checkbox.checked)
        .map((checkbox) => checkbox.dataset.filterLabel)

      summary.innerHTML = ""

      if (selectedLabels.length === 0) {
        summary.insertAdjacentHTML(
          "beforeend",
          '<span class="event-calendars__filter-pill event-calendars__filter-pill--muted">All</span>'
        )
        return
      }

      selectedLabels.forEach((label) => {
        summary.insertAdjacentHTML(
          "beforeend",
          `<span class="event-calendars__filter-pill">${this.escapeHtml(label)}</span>`
        )
      })
    })
  }

  updateClearFiltersButton() {
    if (!this.hasClearFiltersButtonTarget) return
    this.clearFiltersButtonTarget.disabled = !this.hasActiveFilters
  }

  syncBrowserUrl() {
    const nextUrl = this.buildFilteredUrl({ preserveHash: true })
    const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`
    if (nextUrl === currentUrl) return

    window.history.replaceState(window.history.state, "", nextUrl)
  }

  updateReturnArtifacts() {
    const filteredUrl = this.buildFilteredUrl()

    if (this.hasReturnToInputTarget) {
      this.returnToInputTarget.value = filteredUrl
    }

    if (this.hasTimingReturnToInputTarget) {
      this.timingReturnToInputTarget.value = filteredUrl
    }

    this.returnLinkTargets.forEach((link) => {
      const basePath = link.dataset.basePath
      const rowId = link.dataset.rowId
      if (!basePath || !rowId) return

      link.href = this.buildHrefWithReturnTo(basePath, `${filteredUrl}#${rowId}`)
    })
  }

  matchesFilters(rowState, query, activeFilters) {
    if (query.length > 0 && !rowState.searchText.includes(query)) return false

    return FACETS.every((facet) => {
      const selectedValues = activeFilters[facet]
      if (selectedValues.size === 0) return true

      return rowState.filters[facet].some((value) => selectedValues.has(value))
    })
  }

  buildFilteredUrl({ preserveHash = false } = {}) {
    const queryString = this.buildFilterQueryString()
    const hash = preserveHash ? window.location.hash : ""
    return `${window.location.pathname}${queryString ? `?${queryString}` : ""}${hash}`
  }

  buildFilterQueryString() {
    const params = new URLSearchParams()
    const rawQuery = this.hasSearchInputTarget ? this.searchInputTarget.value.trim() : ""

    if (rawQuery.length > 0) params.set("q", rawQuery)

    FACETS.forEach((facet) => {
      const param = FACET_PARAMS[facet]
      this.selectedFilterValuesForParam(param).forEach((value) => {
        params.append(param, value)
      })
    })

    return params.toString()
  }

  buildHrefWithReturnTo(basePath, returnTo) {
    const url = new URL(basePath, window.location.origin)
    url.searchParams.set("return_to", returnTo)
    return `${url.pathname}${url.search}${url.hash}`
  }

  selectedFilterValuesForParam(param) {
    return this.filterCheckboxTargets
      .filter((checkbox) => checkbox.dataset.filterParam === param && checkbox.checked)
      .map((checkbox) => checkbox.value)
  }

  parseFilterValues(rawValue) {
    if (!rawValue) return []

    try {
      const parsed = JSON.parse(rawValue)
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return []
    }
  }

  tokenizeFilterValue(value) {
    if (value === "__none__") return value

    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
  }

  selectedItemById(id) {
    return this.selectedItemData.find((item) => item.id === id)
  }

  itemDataForCheckbox(checkbox) {
    const row = checkbox.closest("[data-calendar-item-id]")
    if (!row) return null

    return {
      id: row.dataset.calendarItemId || "",
      title: row.dataset.calendarItemTitle || "Selected item",
      startAt: row.dataset.calendarItemStartAt || "",
      endAt: row.dataset.calendarItemEndAt || "",
      relative: row.dataset.calendarItemRelative === "true"
    }
  }

  formatDuration(totalMinutes) {
    const monthMinutes = 60 * 24 * 30
    const weekMinutes = 60 * 24 * 7
    const dayMinutes = 60 * 24
    let unit = "days"
    let multiplier = dayMinutes

    if (totalMinutes > 0 && totalMinutes % monthMinutes === 0) {
      unit = "months"
      multiplier = monthMinutes
    } else if (totalMinutes > 0 && totalMinutes % weekMinutes === 0) {
      unit = "weeks"
      multiplier = weekMinutes
    }

    const majorValue = Math.floor(totalMinutes / multiplier)
    const remainder = totalMinutes % multiplier
    const hours = Math.floor(remainder / 60)
    const minutes = remainder % 60
    const parts = []

    if (majorValue > 0) parts.push(`${majorValue} ${majorValue === 1 ? unit.replace(/s$/, "") : unit}`)
    if (hours > 0) parts.push(`${hours} hr`)
    if (minutes > 0) parts.push(`${minutes} min`)

    return parts.length > 0 ? parts.join(" ") : "0 days"
  }

  formatTimingDate(value) {
    if (!value) return ""

    const date = new Date(value)
    if (Number.isNaN(date.getTime())) return ""

    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: this.calendarTimezone,
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true
    })
    const parts = {}

    formatter.formatToParts(date).forEach((part) => {
      if (part.type !== "literal") parts[part.type] = part.value
    })

    const month = parts.month === "Sep" ? "Sept" : parts.month
    return `${month} ${parts.day} ${parts.hour}:${parts.minute}${parts.dayPeriod}`
  }

  updateHighlights(query) {
    if (!this.supportsCustomHighlights()) return

    const normalizedQuery = this.normalizeHighlightText(query)
    if (!normalizedQuery) {
      this.clearHighlights()
      return
    }

    const ranges = this.collectMatchRanges(normalizedQuery)
    if (ranges.length === 0) {
      this.clearHighlights()
      return
    }

    const highlight = new window.Highlight()
    ranges.forEach((range) => highlight.add(range))
    window.CSS.highlights.set(this.constructor.highlightName, highlight)
  }

  clearHighlights() {
    if (!this.supportsCustomHighlights()) return
    window.CSS.highlights.delete(this.constructor.highlightName)
  }

  supportsCustomHighlights() {
    return typeof window.Highlight === "function" &&
      typeof window.CSS !== "undefined" &&
      window.CSS.highlights &&
      typeof window.CSS.highlights.set === "function"
  }

  collectMatchRanges(normalizedQuery) {
    return this.searchableTextTargets.flatMap((element) => {
      const row = element.closest(".event-calendars__row")
      if (row?.hidden) return []

      return this.textNodesFor(element).flatMap((textNode) => {
        const { normalizedText, indexMap } = this.normalizedTextWithIndexMap(textNode.textContent || "")
        if (!normalizedText) return []

        const ranges = []
        let startIndex = 0

        while (startIndex < normalizedText.length) {
          const matchIndex = normalizedText.indexOf(normalizedQuery, startIndex)
          if (matchIndex === -1) break

          const originalStart = indexMap[matchIndex]
          const originalEnd = indexMap[matchIndex + normalizedQuery.length - 1] + 1
          const range = new Range()
          range.setStart(textNode, originalStart)
          range.setEnd(textNode, originalEnd)
          ranges.push(range)
          startIndex = matchIndex + normalizedQuery.length
        }

        return ranges
      })
    })
  }

  textNodesFor(element) {
    const walker = document.createTreeWalker(element, window.NodeFilter.SHOW_TEXT)
    const textNodes = []
    let currentNode = walker.nextNode()

    while (currentNode) {
      textNodes.push(currentNode)
      currentNode = walker.nextNode()
    }

    return textNodes
  }

  normalizedTextWithIndexMap(text) {
    const normalizedCharacters = []
    const indexMap = []
    let lastWasWhitespace = false

    for (let index = 0; index < text.length; index += 1) {
      const character = text[index]

      if (/\s/.test(character)) {
        if (normalizedCharacters.length === 0 || lastWasWhitespace) continue

        normalizedCharacters.push(" ")
        indexMap.push(index)
        lastWasWhitespace = true
        continue
      }

      normalizedCharacters.push(character.toLowerCase())
      indexMap.push(index)
      lastWasWhitespace = false
    }

    while (normalizedCharacters[0] === " ") {
      normalizedCharacters.shift()
      indexMap.shift()
    }

    while (normalizedCharacters[normalizedCharacters.length - 1] === " ") {
      normalizedCharacters.pop()
      indexMap.pop()
    }

    return {
      normalizedText: normalizedCharacters.join(""),
      indexMap
    }
  }

  normalizeHighlightText(text) {
    return String(text || "").toLowerCase().trim().replace(/\s+/g, " ")
  }

  escapeHtml(value) {
    return value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;")
  }

  get activeFilters() {
    return FACETS.reduce((filters, facet) => {
      filters[facet] = new Set(
        this.filterCheckboxTargets
          .filter((checkbox) => checkbox.dataset.filterFacet === facet && checkbox.checked)
          .map((checkbox) => checkbox.value)
      )
      return filters
    }, {})
  }

  get normalizedSearchQuery() {
    return this.normalizeHighlightText(this.currentHighlightQuery)
  }

  get currentHighlightQuery() {
    if (!this.hasSearchInputTarget) return ""

    return this.searchInputTarget.value
  }

  get visibleRowStates() {
    return this.rowStates.filter((rowState) => !rowState.element.hidden)
  }

  get visibleCheckboxes() {
    return this.visibleRowStates
      .map((rowState) => rowState.checkbox)
      .filter((checkbox) => checkbox)
  }

  setGroupSelection(groupKey, checked) {
    if (!groupKey) return

    this.checkboxesForGroup(groupKey).forEach((checkbox) => {
      checkbox.checked = checked
    })

    this.updateSelectionState()
  }

  checkboxesForGroup(groupKey) {
    return this.visibleRowStates
      .filter((rowState) => rowState.groupKey === groupKey)
      .map((rowState) => rowState.checkbox)
      .filter((checkbox) => checkbox)
  }

  get allVisibleRowsSelected() {
    const visibleCheckboxes = this.visibleCheckboxes
    return visibleCheckboxes.length > 0 && visibleCheckboxes.every((checkbox) => checkbox.checked)
  }

  updateGroupSelectionButtons() {
    if (!this.hasGroupRowTarget) return

    this.groupRowTargets.forEach((groupRow) => {
      const groupKey = groupRow.dataset.calendarGroupKey || ""
      const groupCheckboxes = this.checkboxesForGroup(groupKey)
      const allSelected = groupCheckboxes.length > 0 && groupCheckboxes.every((checkbox) => checkbox.checked)
      const anySelected = groupCheckboxes.some((checkbox) => checkbox.checked)

      groupRow.querySelectorAll("[data-group-selection-action='select']").forEach((button) => {
        button.disabled = groupCheckboxes.length === 0 || allSelected
      })

      groupRow.querySelectorAll("[data-group-selection-action='deselect']").forEach((button) => {
        button.disabled = groupCheckboxes.length === 0 || !anySelected
      })
    })
  }

  updateVisibleSelectionButtons() {
    const visibleCount = this.visibleCheckboxes.length
    const label = `${this.allVisibleRowsSelected ? "Deselect" : "Select"} all ${visibleCount} item${visibleCount === 1 ? "" : "s"}`

    this.visibleSelectionButtonTargets.forEach((button) => {
      button.textContent = label
      button.disabled = visibleCount === 0
    })
  }

  get hasActiveFilters() {
    if (this.hasSearchInputTarget && this.searchInputTarget.value.trim().length > 0) return true
    return this.filterCheckboxTargets.some((checkbox) => checkbox.checked)
  }

  get selectedCount() {
    return this.checkboxTargets.filter((checkbox) => checkbox.checked).length
  }

  get selectedCheckboxes() {
    return this.checkboxTargets.filter((checkbox) => checkbox.checked)
  }

  get selectedItemData() {
    return this.selectedCheckboxes
      .map((checkbox) => this.itemDataForCheckbox(checkbox))
      .filter((item) => item)
  }

  get currentAction() {
    return this.hasActionSelectTarget ? this.actionSelectTarget.value : ""
  }

  get currentActionLabel() {
    if (!this.hasActionSelectTarget) return "the selected action"

    const selectedOption = this.actionSelectTarget.selectedOptions[0]
    return selectedOption?.textContent?.trim() || "the selected action"
  }

  get dialogOpen() {
    if (!this.hasDialogTarget) return false
    if ("open" in this.dialogTarget) return this.dialogTarget.open

    return this.dialogTarget.hasAttribute("open")
  }

  get timingDialogOpen() {
    if (!this.hasRelativeTimingDialogTarget) return false
    if ("open" in this.relativeTimingDialogTarget) return this.relativeTimingDialogTarget.open

    return this.relativeTimingDialogTarget.hasAttribute("open")
  }

  get calendarTimezone() {
    return this.element.dataset.calendarTimezone || undefined
  }
}
