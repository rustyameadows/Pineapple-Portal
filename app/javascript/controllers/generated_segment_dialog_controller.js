import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    autoOpen: Boolean
  }

  connect() {
    if (this.autoOpenValue) {
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
    if (!this.hasDialogTarget) return

    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "open")
    }
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
    if (this.lastTrigger) {
      this.lastTrigger.focus()
    }
  }

  isOpen() {
    return this.hasDialogTarget && this.dialogTarget.hasAttribute("open")
  }
}
