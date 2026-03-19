import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "actionLabel",
    "actionSelect",
    "applyButton",
    "checkbox",
    "dialog",
    "form",
    "locationRow",
    "panel",
    "selectionCount",
    "tableShell",
    "tagsRow",
    "vendorRow"
  ]

  connect() {
    this.updateSelectionState()
    this.updateActionState()
  }

  selectionChanged() {
    this.updateSelectionState()
  }

  actionChanged() {
    this.updateActionState()
  }

  selectAll() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = true
    })

    this.updateSelectionState()
  }

  clearSelection() {
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = false
    })

    this.closeDialog()
    this.updateSelectionState()
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

  closeDialog() {
    if (!this.hasDialogTarget) return
    if (!this.dialogOpen) return

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
    this.updateApplyState()
  }

  updateActionState() {
    const action = this.currentAction
    const showTags = action === "add_tags" || action === "remove_tags"
    const showVendor = action === "set_vendor"
    const showLocation = action === "set_location"

    if (this.hasTagsRowTarget) this.tagsRowTarget.hidden = !showTags
    if (this.hasVendorRowTarget) this.vendorRowTarget.hidden = !showVendor
    if (this.hasLocationRowTarget) this.locationRowTarget.hidden = !showLocation

    this.updateApplyState()
  }

  updateApplyState() {
    if (!this.hasApplyButtonTarget) return
    this.applyButtonTarget.disabled = !this.hasSelection || !this.currentAction
  }

  get selectedCount() {
    return this.checkboxTargets.filter((checkbox) => checkbox.checked).length
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
}
