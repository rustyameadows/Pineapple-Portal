import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item", "handle"]
  static values = {
    reorderUrl: String,
    csrfToken: String
  }

  connect() {
    this.draggingItem = null
    this.draggingAllowed = false
    this.pressStartHandler = this.handlePressStart.bind(this)
    this.pressEndHandler = this.handlePressEnd.bind(this)
    this.dragStartHandler = this.handleDragStart.bind(this)
    this.dragOverHandler = this.handleDragOver.bind(this)
    this.dropHandler = this.handleDrop.bind(this)
    this.dragEndHandler = this.handleDragEnd.bind(this)

    this.element.addEventListener("mousedown", this.pressStartHandler)
    this.element.addEventListener("touchstart", this.pressStartHandler)
    this.element.addEventListener("mouseup", this.pressEndHandler)
    this.element.addEventListener("touchend", this.pressEndHandler)
    this.element.addEventListener("touchcancel", this.pressEndHandler)
    this.element.addEventListener("dragstart", this.dragStartHandler)
    this.element.addEventListener("dragover", this.dragOverHandler)
    this.element.addEventListener("drop", this.dropHandler)
    this.element.addEventListener("dragend", this.dragEndHandler)

    this.itemTargets.forEach((item) => {
      item.setAttribute("draggable", "true")
    })
  }

  disconnect() {
    this.element.removeEventListener("mousedown", this.pressStartHandler)
    this.element.removeEventListener("touchstart", this.pressStartHandler)
    this.element.removeEventListener("mouseup", this.pressEndHandler)
    this.element.removeEventListener("touchend", this.pressEndHandler)
    this.element.removeEventListener("touchcancel", this.pressEndHandler)
    this.element.removeEventListener("dragstart", this.dragStartHandler)
    this.element.removeEventListener("dragover", this.dragOverHandler)
    this.element.removeEventListener("drop", this.dropHandler)
    this.element.removeEventListener("dragend", this.dragEndHandler)
  }

  itemTargetConnected(element) {
    element.setAttribute("draggable", "true")
  }

  handlePressStart(event) {
    this.draggingAllowed = Boolean(event.target.closest(".generated-builder__drag-handle"))
  }

  handlePressEnd() {
    this.draggingAllowed = false
  }

  handleDragStart(event) {
    const item = event.target.closest("[data-segment-id]")

    if (!this.draggingAllowed || !item) {
      event.preventDefault()
      return
    }

    this.draggingItem = item
    this.draggingAllowed = false
    this.draggingItem.classList.add("generated-builder__list-item--dragging")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", item.dataset.segmentId || "")
    }
  }

  handleDragOver(event) {
    if (!this.draggingItem) return
    event.preventDefault()

    const target = event.target.closest("[data-segment-id]")
    if (!target || target === this.draggingItem) return

    const rect = target.getBoundingClientRect()
    const offset = event.clientY - rect.top
    const shouldInsertAfter = offset > rect.height / 2

    if (shouldInsertAfter) {
      target.after(this.draggingItem)
    } else {
      target.before(this.draggingItem)
    }
  }

  handleDrop(event) {
    if (!this.draggingItem) return
    event.preventDefault()
    this.finalizeDrag()
  }

  handleDragEnd() {
    if (!this.draggingItem) return
    this.finalizeDrag()
  }

  finalizeDrag() {
    if (!this.draggingItem) return
    this.draggingItem.classList.remove("generated-builder__list-item--dragging")
    this.draggingItem = null
    this.persistOrder()
  }

  persistOrder() {
    if (!this.hasReorderUrlValue || !this.reorderUrlValue) return

    const ids = Array.from(
      this.element.querySelectorAll("[data-segment-id]")
    )
      .map((item) => item.dataset.segmentId)
      .filter(Boolean)

    if (ids.length === 0) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("segment_ids[]", id))

    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-CSRF-Token": this.csrfTokenValue || ""
      },
      body: body.toString(),
      credentials: "same-origin"
    })
      .then((response) => {
        if (response.ok) {
          this.showToast("Segment order saved.")
        } else {
          this.showToast("Unable to save segment order", "alert")
        }
      })
      .catch(() => this.showToast("Unable to save segment order", "alert"))
  }

  showToast(message, type = "notice") {
    const toast = document.createElement("div")
    toast.className = `flash flash-${type} flash-toast`
    toast.textContent = message
    document.body.prepend(toast)
    setTimeout(() => toast.remove(), 2200)
  }
}
