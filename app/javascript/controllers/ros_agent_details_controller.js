import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["taskDialog", "canvasDialog"]

  open(event) {
    this.openCanvas(event)
  }

  openTask(event) {
    this.openDialog(this.hasTaskDialogTarget ? this.taskDialogTarget : null, event)
  }

  openCanvas(event) {
    this.openDialog(this.hasCanvasDialogTarget ? this.canvasDialogTarget : null, event)
  }

  close(event) {
    if (event) event.preventDefault()
    this.hideDialog(this.openDialogTarget())
    this.restoreFocus()
  }

  handleCancel(event) {
    event.preventDefault()
    this.close()
  }

  handleBackdropClose(event) {
    if (!this.dialogTargets().includes(event.target)) return
    this.close()
  }

  openDialog(dialog, event) {
    if (event) event.preventDefault()
    if (!dialog) return

    this.lastTrigger = event?.currentTarget
    this.showDialog(dialog)
  }

  showDialog(dialog) {
    if (!dialog) return

    if (typeof dialog.showModal === "function") {
      dialog.showModal()
    } else {
      dialog.setAttribute("open", "open")
    }
  }

  hideDialog(dialog) {
    if (!dialog || !dialog.hasAttribute("open")) return

    if (typeof dialog.close === "function") {
      dialog.close()
    } else {
      dialog.removeAttribute("open")
    }
  }

  openDialogTarget() {
    return this.dialogTargets().find((dialog) => dialog.hasAttribute("open"))
  }

  dialogTargets() {
    return [
      this.hasTaskDialogTarget ? this.taskDialogTarget : null,
      this.hasCanvasDialogTarget ? this.canvasDialogTarget : null
    ].filter(Boolean)
  }

  restoreFocus() {
    if (this.lastTrigger) this.lastTrigger.focus()
  }
}
