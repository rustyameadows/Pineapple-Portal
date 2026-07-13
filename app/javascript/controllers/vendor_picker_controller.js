import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "row", "empty", "radio", "submit", "count"]

  connect() {
    this.filter()
    this.syncSelection()
  }

  filter() {
    const query = this.normalizedQuery
    let visibleCount = 0

    this.rowTargets.forEach((row) => {
      const visible = row.dataset.searchText.includes(query)
      row.hidden = !visible
      if (visible) visibleCount += 1

      if (!visible) {
        const radio = row.querySelector("input[type='radio']")
        if (radio?.checked) radio.checked = false
      }
    })

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visibleCount > 0
    if (this.hasCountTarget) this.countTarget.textContent = `${visibleCount} available`
    this.syncSelection()
  }

  syncSelection() {
    const hasSelection = this.radioTargets.some((radio) => radio.checked && !radio.closest("tr")?.hidden)
    if (this.hasSubmitTarget) this.submitTarget.disabled = !hasSelection
  }

  get normalizedQuery() {
    return this.hasQueryTarget ? this.queryTarget.value.trim().toLowerCase() : ""
  }
}
