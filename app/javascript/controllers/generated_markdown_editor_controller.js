import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "dialog", "overlay", "openButton"]

  connect() {
    if (this.hasOpenButtonTarget) {
      this.openButtonTarget.hidden = false
    }
  }

  disconnect() {
    this.hideDialog()
  }

  open(event) {
    event.preventDefault()
    this.lastOpenButton = event.currentTarget
    this.syncOverlayFromSource()
    this.showDialog()
    this.focusOverlay()
  }

  close(event) {
    if (event) event.preventDefault()
    this.hideDialog()
    this.restoreFocus()
  }

  syncFromOverlay() {
    if (!this.hasOverlayTarget || !this.hasSourceTarget) return
    if (this.sourceTarget.value === this.overlayTarget.value) return

    this.sourceTarget.value = this.overlayTarget.value
    this.sourceTarget.dispatchEvent(new Event("input", { bubbles: true }))
  }

  syncFromSource() {
    if (!this.isDialogOpen() || !this.hasOverlayTarget || !this.hasSourceTarget) return
    if (this.overlayTarget.value === this.sourceTarget.value) return

    this.overlayTarget.value = this.sourceTarget.value
  }

  handleCancel(event) {
    event.preventDefault()
    this.close()
  }

  handleBackdropClose(event) {
    if (!this.hasDialogTarget || event.target !== this.dialogTarget) return
    this.close()
  }

  syncOverlayFromSource() {
    if (!this.hasOverlayTarget || !this.hasSourceTarget) return
    this.overlayTarget.value = this.sourceTarget.value
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
    if (!this.hasDialogTarget || !this.isDialogOpen()) return

    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  focusOverlay() {
    if (!this.hasOverlayTarget) return
    requestAnimationFrame(() => this.overlayTarget.focus())
  }

  restoreFocus() {
    const focusTarget = this.lastOpenButton || (this.hasOpenButtonTarget ? this.openButtonTarget : null)
    if (!focusTarget) return
    focusTarget.focus()
  }

  isDialogOpen() {
    return this.hasDialogTarget && this.dialogTarget.hasAttribute("open")
  }
}
