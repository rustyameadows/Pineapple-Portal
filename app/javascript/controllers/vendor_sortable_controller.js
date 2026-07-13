import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "item", "handle"]
  static values = {
    reorderUrl: String,
    csrfToken: String
  }

  connect() {
    this.draggingItem = null
    this.originalOrder = []
    this.dragStartHandler = this.handleDragStart.bind(this)
    this.dragOverHandler = this.handleDragOver.bind(this)
    this.dropHandler = this.handleDrop.bind(this)
    this.dragEndHandler = this.handleDragEnd.bind(this)

    if (this.hasListTarget) {
      this.listTarget.addEventListener("dragstart", this.dragStartHandler)
      this.listTarget.addEventListener("dragover", this.dragOverHandler)
      this.listTarget.addEventListener("drop", this.dropHandler)
      this.listTarget.addEventListener("dragend", this.dragEndHandler)
    }

  }

  disconnect() {
    if (!this.hasListTarget) return

    this.listTarget.removeEventListener("dragstart", this.dragStartHandler)
    this.listTarget.removeEventListener("dragover", this.dragOverHandler)
    this.listTarget.removeEventListener("drop", this.dropHandler)
    this.listTarget.removeEventListener("dragend", this.dragEndHandler)
  }

  handleDragStart(event) {
    const handle = event.target.closest(".event-settings__vendor-drag-handle")
    const item = this.ownItemFrom(event)
    if (!handle || !item || handle.closest("[data-controller~='vendor-sortable']") !== this.element) {
      event.preventDefault()
      return
    }

    this.originalOrder = this.orderedIds
    this.draggingItem = item
    this.draggingItem.classList.add("event-settings__vendor-roster-group--dragging")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", item.dataset.eventVendorId || "")
    }
  }

  handleDragOver(event) {
    if (!this.draggingItem) return

    const target = this.ownItemFrom(event)
    if (!target || target === this.draggingItem) return

    event.preventDefault()
    const rect = target.getBoundingClientRect()
    const insertAfter = event.clientY - rect.top > rect.height / 2

    if (insertAfter) {
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
    this.draggingItem.classList.remove("event-settings__vendor-roster-group--dragging")
    this.draggingItem = null
    this.persistOrder()
  }

  persistOrder() {
    if (!this.hasReorderUrlValue || !this.reorderUrlValue) return

    const ids = this.orderedIds
    if (ids.length === 0 || ids.join(",") === this.originalOrder.join(",")) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("event_vendor_ids[]", id))

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
        if (!response.ok) throw new Error("Unable to save vendor order")
        this.originalOrder = ids
        this.showToast("Vendor order saved.")
      })
      .catch(() => {
        this.restoreOriginalOrder()
        this.showToast("Unable to save vendor order", "alert")
      })
  }

  restoreOriginalOrder() {
    this.originalOrder.forEach((id) => {
      const item = this.itemTargets.find((candidate) => candidate.dataset.eventVendorId === id)
      if (item) this.listTarget.append(item)
    })
  }

  ownItemFrom(event) {
    const item = event.target.closest("[data-vendor-sortable-target~='item']")
    if (!item) return null

    return item.closest("[data-controller~='vendor-sortable']") === this.element ? item : null
  }

  get orderedIds() {
    return this.itemTargets.map((item) => item.dataset.eventVendorId).filter(Boolean)
  }

  showToast(message, type = "notice") {
    const container = document.querySelector(".flash-toast-container")
    if (!container) return

    const toast = document.createElement("div")
    toast.className = `flash flash-${type} flash-toast`
    toast.textContent = message
    container.prepend(toast)
    setTimeout(() => toast.remove(), 2200)
  }
}
