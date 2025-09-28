import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "item", "handle", "viewButton"]
  static values = {
    reorderUrl: String,
    csrfToken: String,
    viewMode: String
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

    const storedMode = this.loadViewModePreference()
    const initialMode = this.viewModeValue || storedMode || "grid"
    this.setViewMode(initialMode, { persist: false })
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

    const source = this.hasListTarget ? this.listTarget : this.element
    const ids = Array.from(
      source.querySelectorAll("[data-segment-id]")
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

  changeView(event) {
    const view = event.currentTarget?.dataset?.view
    if (!view) return
    this.setViewMode(view)
  }

  viewModeValueChanged(value) {
    this.applyViewMode(value)
  }

  setViewMode(value, { persist = true } = {}) {
    const mode = value === "grid" ? "grid" : "list"
    if (this.viewModeValue === mode) {
      this.applyViewMode(mode)
      if (persist) this.storeViewModePreference(mode)
      return
    }

    this.viewModeValue = mode
    if (persist) this.storeViewModePreference(mode)
  }

  applyViewMode(mode) {
    const view = mode === "grid" ? "grid" : "list"
    if (this.hasListTarget) {
      this.listTarget.classList.toggle("generated-builder__list--grid", view === "grid")
    }

    this.viewButtonTargets.forEach((button) => {
      const isActive = button.dataset.view === view
      button.classList.toggle("generated-builder__view-button--active", isActive)
      button.setAttribute("aria-pressed", isActive ? "true" : "false")
    })
  }

  loadViewModePreference() {
    try {
      return window.localStorage.getItem("generatedSegmentsViewMode")
    } catch (error) {
      return null
    }
  }

  storeViewModePreference(mode) {
    try {
      window.localStorage.setItem("generatedSegmentsViewMode", mode)
    } catch (error) {
      // ignore persistence errors (e.g., private mode)
    }
  }

  showToast(message, type = "notice") {
    const toast = document.createElement("div")
    toast.className = `flash flash-${type} flash-toast`
    toast.textContent = message
    document.body.prepend(toast)
    setTimeout(() => toast.remove(), 2200)
  }
}
