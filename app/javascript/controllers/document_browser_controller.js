import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static highlightName = "document-browser-search-match"
  static targets = [
    "searchInput",
    "tablePane",
    "gridPane",
    "tableRow",
    "gridCard",
    "titleText",
    "searchEmpty",
    "tableButton",
    "gridButton"
  ]

  connect() {
    this.setView("table")
    this.filter()
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
}
