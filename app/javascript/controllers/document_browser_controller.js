import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "searchInput",
    "tablePane",
    "gridPane",
    "tableRow",
    "gridCard",
    "searchEmpty",
    "tableButton",
    "gridButton"
  ]

  connect() {
    this.setView("table")
    this.filter()
  }

  filter() {
    const query = this.hasSearchInputTarget ? this.searchInputTarget.value.trim().toLowerCase() : ""
    let visibleRows = 0

    this.tableRowTargets.forEach((row) => {
      const visible = this.matchesQuery(row, query)
      row.hidden = !visible
      if (visible) visibleRows += 1
    })

    this.gridCardTargets.forEach((card) => {
      card.hidden = !this.matchesQuery(card, query)
    })

    if (this.hasSearchEmptyTarget) {
      this.searchEmptyTarget.hidden = visibleRows > 0
    }
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
}
