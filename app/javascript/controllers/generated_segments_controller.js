import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "item", "handle"]
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

    if (this.hasListTarget) {
      this.listTarget.addEventListener("mousedown", this.pressStartHandler)
      this.listTarget.addEventListener("touchstart", this.pressStartHandler)
      this.listTarget.addEventListener("mouseup", this.pressEndHandler)
      this.listTarget.addEventListener("touchend", this.pressEndHandler)
      this.listTarget.addEventListener("touchcancel", this.pressEndHandler)
      this.listTarget.addEventListener("dragstart", this.dragStartHandler)
      this.listTarget.addEventListener("dragover", this.dragOverHandler)
      this.listTarget.addEventListener("drop", this.dropHandler)
      this.listTarget.addEventListener("dragend", this.dragEndHandler)
    }

    this.itemTargets.forEach((item) => {
      item.setAttribute("draggable", "true")
    })
  }

  disconnect() {
    if (this.hasListTarget) {
      this.listTarget.removeEventListener("mousedown", this.pressStartHandler)
      this.listTarget.removeEventListener("touchstart", this.pressStartHandler)
      this.listTarget.removeEventListener("mouseup", this.pressEndHandler)
      this.listTarget.removeEventListener("touchend", this.pressEndHandler)
      this.listTarget.removeEventListener("touchcancel", this.pressEndHandler)
      this.listTarget.removeEventListener("dragstart", this.dragStartHandler)
      this.listTarget.removeEventListener("dragover", this.dragOverHandler)
      this.listTarget.removeEventListener("drop", this.dropHandler)
      this.listTarget.removeEventListener("dragend", this.dragEndHandler)
    }
  }

  itemTargetConnected(element) {
    element.setAttribute("draggable", "true")
  }

  handlePressStart(event) {
    const handle = event.target.closest(".generated-builder__drag-handle")
    this.draggingAllowed = Boolean(handle && handle.closest("[data-generated-segments-root]") === this.element)
  }

  handlePressEnd() {
    this.draggingAllowed = false
  }

  handleDragStart(event) {
    const item = this.ownItemFrom(event)

    if (!item) return

    if (!this.draggingAllowed) {
      event.preventDefault()
      return
    }

    this.draggingItem = item
    this.draggingAllowed = false
    this.draggingItem.classList.add("generated-builder__toc-item--dragging")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", item.dataset.segmentId || "")
    }
  }

  handleDragOver(event) {
    if (!this.draggingItem) return

    const target = this.ownItemFrom(event)
    if (!target || target === this.draggingItem) return

    event.preventDefault()

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
    this.draggingItem.classList.remove("generated-builder__toc-item--dragging")
    this.draggingItem = null
    this.persistOrder()
  }

  persistOrder() {
    if (!this.hasReorderUrlValue || !this.reorderUrlValue) return

    const source = this.hasListTarget ? this.listTarget : this.element
    const ids = Array.from(source.children)
      .filter((item) => item.matches("[data-segment-id]"))
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

  ownItemFrom(event) {
    const item = event.target.closest("[data-segment-id]")
    if (!item) return null

    return item.closest("[data-generated-segments-root]") === this.element ? item : null
  }

  showToast(message, type = "notice") {
    const toast = document.createElement("div")
    toast.className = `flash flash-${type} flash-toast`
    toast.textContent = message
    document.body.prepend(toast)
    setTimeout(() => toast.remove(), 2200)
  }
}
