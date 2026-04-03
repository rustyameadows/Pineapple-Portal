import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static highlightName = "document-browser-search-match"
  static targets = [
    "searchInput",
    "tablePane",
    "gridPane",
    "tableBody",
    "gridList",
    "tableRow",
    "gridCard",
    "gridImage",
    "titleText",
    "searchEmpty",
    "sortHeader",
    "sortButton",
    "tableButton",
    "gridButton"
  ]

  connect() {
    this.activeSortKey = null
    this.currentView = "table"
    this.sortDirection = "asc"
    this.setView("table")
    this.filter()
    this.updateSortUi()
  }

  disconnect() {
    this.clearHighlights()
  }

  filter() {
    const query = this.currentQuery()
    const normalizedQuery = query.toLowerCase()
    let visibleRows = 0

    this.tableRowTargets.forEach((row) => {
      const visible = this.matchesQuery(row, normalizedQuery)
      row.hidden = !visible
      if (visible) visibleRows += 1
    })

    this.gridCardTargets.forEach((card) => {
      card.hidden = !this.matchesQuery(card, normalizedQuery)
    })

    if (this.isGridActive()) this.hydrateVisibleGridMedia()

    if (this.hasSearchEmptyTarget) {
      this.searchEmptyTarget.hidden = visibleRows > 0
    }

    this.updateHighlights(query)
  }

  showTable(event) {
    if (event) event.preventDefault()
    this.setView("table")
  }

  showGrid(event) {
    if (event) event.preventDefault()
    this.setView("grid")
    this.hydrateVisibleGridMedia()
  }

  sort(event) {
    event.preventDefault()
    event.stopPropagation()

    const key = event.currentTarget.dataset.sortKey
    if (!key) return

    this.sortDirection = this.activeSortKey === key && this.sortDirection === "asc" ? "desc" : "asc"
    this.activeSortKey = key
    this.applySort()
  }

  navigate(event) {
    if (this.shouldIgnoreNavigation(event)) return

    if (event.type === "keydown") {
      event.preventDefault()
    }

    const url = event.currentTarget.dataset.url
    if (url) window.location.assign(url)
  }

  setView(view) {
    const tableActive = view !== "grid"
    this.currentView = tableActive ? "table" : "grid"

    if (this.hasTablePaneTarget) this.tablePaneTarget.hidden = !tableActive
    if (this.hasGridPaneTarget) this.gridPaneTarget.hidden = tableActive
    if (this.hasTableButtonTarget) {
      this.tableButtonTarget.classList.toggle("documents-browser__toggle-button--active", tableActive)
      this.tableButtonTarget.setAttribute("aria-pressed", tableActive ? "true" : "false")
    }
    if (this.hasGridButtonTarget) {
      this.gridButtonTarget.classList.toggle("documents-browser__toggle-button--active", !tableActive)
      this.gridButtonTarget.setAttribute("aria-pressed", tableActive ? "false" : "true")
    }
  }

  hydrateVisibleGridMedia() {
    this.gridImageTargets.forEach((image) => {
      const card = image.closest(".documents-browser__card")
      if (card?.hidden) return
      if (!image) return
      if (image.dataset.mediaLoaded === "true" || image.getAttribute("src")) return

      const mediaUrl = image.dataset.mediaUrl
      if (!mediaUrl) return

      image.loading = "lazy"
      image.decoding = "async"
      image.src = mediaUrl
      image.dataset.mediaLoaded = "true"
    })
  }

  isGridActive() {
    return this.currentView === "grid"
  }

  matchesQuery(element, query) {
    if (!query) return true

    const searchText = element.dataset.searchText || ""
    return searchText.includes(query)
  }

  shouldIgnoreNavigation(event) {
    return Boolean(event.target.closest("a, button, input, select, textarea, label"))
  }

  currentQuery() {
    return this.hasSearchInputTarget ? this.searchInputTarget.value.trim() : ""
  }

  applySort() {
    if (!this.activeSortKey) {
      this.updateSortUi()
      return
    }

    const sortedKeys = this.sortedItemKeys()
    this.reorderContainer(this.tableBodyTarget, this.tableRowTargets, sortedKeys)
    this.reorderContainer(this.gridListTarget, this.gridCardTargets, sortedKeys)
    this.updateSortUi()
    this.filter()
  }

  updateHighlights(query) {
    if (!this.supportsCustomHighlights()) return

    const normalizedQuery = query.toLowerCase()
    if (!normalizedQuery) {
      this.clearHighlights()
      return
    }

    const ranges = this.collectMatchRanges(normalizedQuery, query.length)
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

  collectMatchRanges(normalizedQuery, queryLength) {
    return this.titleTextTargets.flatMap((element) => {
      const container = element.closest(".documents-browser__row, .documents-browser__card")
      if (container?.hidden) return []

      const textNode = this.textNodeFor(element)
      if (!textNode) return []

      const textContent = textNode.textContent || ""
      const normalizedText = textContent.toLowerCase()
      const ranges = []
      let startIndex = 0

      while (startIndex < normalizedText.length) {
        const matchIndex = normalizedText.indexOf(normalizedQuery, startIndex)
        if (matchIndex === -1) break

        const range = new Range()
        range.setStart(textNode, matchIndex)
        range.setEnd(textNode, matchIndex + queryLength)
        ranges.push(range)
        startIndex = matchIndex + queryLength
      }

      return ranges
    })
  }

  textNodeFor(element) {
    return Array.from(element.childNodes).find((node) => node.nodeType === Node.TEXT_NODE)
  }

  sortedItemKeys() {
    const entries = this.tableRowTargets.map((row, index) => {
      return {
        itemKey: row.dataset.itemKey,
        originalIndex: index,
        sortValues: this.sortValuesFor(row)
      }
    })

    entries.sort((left, right) => this.compareEntries(left, right))
    return entries.map((entry) => entry.itemKey)
  }

  compareEntries(left, right) {
    const leftValue = left.sortValues[this.activeSortKey]
    const rightValue = right.sortValues[this.activeSortKey]
    const leftMissing = this.isMissingValue(leftValue)
    const rightMissing = this.isMissingValue(rightValue)

    if (leftMissing && rightMissing) return left.originalIndex - right.originalIndex
    if (leftMissing) return 1
    if (rightMissing) return -1

    let comparison = 0
    if (typeof leftValue === "number" && typeof rightValue === "number") {
      comparison = leftValue - rightValue
    } else {
      comparison = String(leftValue).localeCompare(String(rightValue), undefined, {
        numeric: true,
        sensitivity: "base"
      })
    }

    if (comparison === 0) return left.originalIndex - right.originalIndex
    return this.sortDirection === "asc" ? comparison : -comparison
  }

  reorderContainer(container, elements, itemKeys) {
    const elementByKey = new Map(elements.map((element) => [element.dataset.itemKey, element]))
    itemKeys.forEach((itemKey) => {
      const element = elementByKey.get(itemKey)
      if (element) container.appendChild(element)
    })
  }

  sortValuesFor(element) {
    try {
      return JSON.parse(element.dataset.sortValues || "{}")
    } catch (error) {
      return {}
    }
  }

  isMissingValue(value) {
    return value === null || value === undefined || value === ""
  }

  updateSortUi() {
    this.sortHeaderTargets.forEach((header) => {
      const isActive = header.dataset.sortKey === this.activeSortKey
      header.setAttribute("aria-sort", isActive ? (this.sortDirection === "asc" ? "ascending" : "descending") : "none")
    })

    this.sortButtonTargets.forEach((button) => {
      const isActive = button.dataset.sortKey === this.activeSortKey
      button.classList.toggle("documents-browser__sort-button--active", isActive)

      const indicator = button.querySelector(".documents-browser__sort-indicator")
      if (!indicator) return

      indicator.textContent = isActive ? (this.sortDirection === "asc" ? "ASC" : "DSC") : ""
      indicator.hidden = !isActive
    })
  }
}
