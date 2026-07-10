import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "trigger"]
  static values = {
    autoOpen: Boolean,
    autoOpenParam: { type: String, default: "event_vendor_id" },
    vendorId: String
  }

  connect() {
    if (this.shouldAutoOpen()) {
      this.lastTrigger = this.hasTriggerTarget ? this.triggerTarget : null
      this.showDialog()
    }
  }

  open(event) {
    event.preventDefault()
    this.lastTrigger = event.currentTarget
    this.showDialog()
  }

  close(event) {
    if (event) event.preventDefault()
    this.hideDialog()
    this.restoreFocus()
  }

  handleCancel(event) {
    event.preventDefault()
    this.close()
  }

  handleBackdropClose(event) {
    if (!this.hasDialogTarget || event.target !== this.dialogTarget) return

    this.close()
  }

  showDialog() {
    if (!this.hasDialogTarget || this.isOpen()) return

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }

    this.focusInitialElement()
  }

  hideDialog() {
    if (!this.hasDialogTarget || !this.isOpen()) return

    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  restoreFocus() {
    if (this.lastTrigger && this.lastTrigger.isConnected) {
      this.lastTrigger.focus()
    }
  }

  focusInitialElement() {
    window.requestAnimationFrame(() => {
      if (!this.isOpen()) return

      const focusTarget = this.dialogTarget.querySelector(
        "[autofocus], input:not([type='hidden']):not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [href], [tabindex]:not([tabindex='-1'])"
      )

      if (focusTarget) focusTarget.focus()
    })
  }

  shouldAutoOpen() {
    if (this.autoOpenValue) return true
    if (!this.hasVendorIdValue || !this.autoOpenParamValue) return false

    const params = new URLSearchParams(window.location.search)
    return params.get(this.autoOpenParamValue) === this.vendorIdValue
  }

  isOpen() {
    return this.hasDialogTarget && this.dialogTarget.hasAttribute("open")
  }
}
