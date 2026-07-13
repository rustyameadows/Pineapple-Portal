import { Controller } from "@hotwired/stimulus"

class GeneratedSegmentsController extends Controller {
  static targets = ["list", "item", "handle"]
  static values = {
    reorderUrl: String,
    relocateUrl: String,
    csrfToken: String
  }

  static activeDrag = null

  connect() {
    this.draggingAllowed = false
    this.pressStartHandler = this.handlePressStart.bind(this)
    this.pressEndHandler = this.handlePressEnd.bind(this)
    this.dragStartHandler = this.handleDragStart.bind(this)
    this.dragOverHandler = this.handleDragOver.bind(this)
    this.dragLeaveHandler = this.handleDragLeave.bind(this)
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
      this.listTarget.addEventListener("dragleave", this.dragLeaveHandler)
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
      this.listTarget.removeEventListener("dragleave", this.dragLeaveHandler)
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
    const sourceList = this.ownListFrom(event)

    if (!item || !sourceList) return

    if (!this.draggingAllowed) {
      event.preventDefault()
      return
    }

    this.draggingAllowed = false
    this.constructor.activeDrag = {
      item,
      itemKind: this.itemKind(item),
      segmentId: item.dataset.segmentId || "",
      sourceController: this,
      sourceList,
      sourceContainer: this.containerMetadata(sourceList),
      sourceIndex: this.directItems(sourceList).indexOf(item),
      sourceNextSibling: item.nextElementSibling,
      destinationController: this,
      destinationList: sourceList,
      dropAccepted: false
    }

    item.classList.add("generated-builder__toc-item--dragging")

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move"
      event.dataTransfer.setData("text/plain", item.dataset.segmentId || "")
    }
  }

  handleDragOver(event) {
    const drag = this.constructor.activeDrag
    const destinationList = this.ownListFrom(event)
    if (!drag || !destinationList) return

    const destinationContainer = this.containerMetadata(destinationList)
    if (!this.dropAllowed(drag, destinationContainer, destinationList)) return

    event.preventDefault()
    if (event.dataTransfer) event.dataTransfer.dropEffect = "move"

    const target = this.ownItemFrom(event)
    if (!target || target === drag.item) {
      if (event.target === destinationList || !target) destinationList.append(drag.item)
    } else {
      const rect = this.dropReferenceRect(target)
      const shouldInsertAfter = event.clientY - rect.top > rect.height / 2
      target[shouldInsertAfter ? "after" : "before"](drag.item)
    }

    this.markDropTarget(drag, destinationList)
    drag.destinationController = this
    drag.destinationList = destinationList
  }

  handleDragLeave(event) {
    const drag = this.constructor.activeDrag
    if (!drag || drag.destinationList !== this.listTarget) return
    if (this.listTarget.contains(event.relatedTarget)) return

    this.clearDropTarget(drag)
  }

  handleDrop(event) {
    const drag = this.constructor.activeDrag
    const destinationList = this.ownListFrom(event)
    if (!drag || !destinationList || destinationList !== drag.destinationList) return

    const destinationContainer = this.containerMetadata(destinationList)
    if (!this.dropAllowed(drag, destinationContainer, destinationList)) return

    event.preventDefault()
    const confirmation = this.sharedMoveConfirmation(drag.sourceContainer, destinationContainer)
    if (confirmation && !window.confirm(confirmation)) {
      this.restoreOriginalPosition(drag)
      this.cleanupDrag(drag)
      return
    }

    drag.dropAccepted = true
    this.finalizeDrag(drag)
  }

  handleDragEnd() {
    const drag = this.constructor.activeDrag
    if (!drag) return

    if (!drag.dropAccepted) this.restoreOriginalPosition(drag)
    this.cleanupDrag(drag)
  }

  finalizeDrag(drag) {
    const destinationList = drag.destinationList
    const movedBetweenContainers = destinationList !== drag.sourceList

    this.cleanupDrag(drag)

    if (movedBetweenContainers) {
      this.persistRelocation(drag)
    } else {
      drag.destinationController.persistOrder(destinationList)
    }
  }

  persistOrder(list = this.listTarget) {
    const reorderUrl = list.dataset.reorderUrl || this.reorderUrlValue
    if (!reorderUrl) return

    const ids = this.directItems(list)
      .map((item) => item.dataset.segmentId)
      .filter(Boolean)

    if (ids.length === 0) return

    const body = new URLSearchParams()
    ids.forEach((id) => body.append("segment_ids[]", id))
    this.setListState(list, "pending")

    fetch(reorderUrl, {
      method: "PATCH",
      headers: this.requestHeaders(),
      body: body.toString(),
      credentials: "same-origin"
    })
      .then((response) => {
        this.setListState(list, response.ok ? null : "error")
        if (response.ok) {
          this.showToast("Segment order saved.")
        } else {
          this.showToast("Unable to save segment order", "alert")
        }
      })
      .catch(() => {
        this.setListState(list, "error")
        this.showToast("Unable to save segment order", "alert")
      })
  }

  persistRelocation(drag) {
    const destinationContainer = this.containerMetadata(drag.destinationList)
    const relocateUrl = this.relocateUrlFor(drag)
    const targetPosition = this.directItems(drag.destinationList).indexOf(drag.item) + 1

    if (!relocateUrl || !drag.segmentId || targetPosition < 1) {
      this.relocationFailed(drag, "Unable to move page: relocation metadata is missing.", { reload: false })
      return
    }

    const body = new URLSearchParams({
      segment_id: drag.segmentId,
      source_container_logical_id: drag.sourceContainer.logicalId,
      source_container_kind: drag.sourceContainer.kind,
      target_container_logical_id: destinationContainer.logicalId,
      target_container_kind: destinationContainer.kind,
      target_position: targetPosition.toString()
    })

    const packetLogicalId = destinationContainer.packetLogicalId || drag.sourceContainer.packetLogicalId
    if (packetLogicalId) body.set("packet_logical_id", packetLogicalId)
    if (drag.sourceContainer.groupPlacementId) body.set("source_group_placement_id", drag.sourceContainer.groupPlacementId)
    if (destinationContainer.groupPlacementId) body.set("target_group_placement_id", destinationContainer.groupPlacementId)

    drag.item.classList.add("generated-builder__toc-item--pending")
    drag.item.setAttribute("aria-busy", "true")
    this.setListState(drag.sourceList, "pending")
    this.setListState(drag.destinationList, "pending")
    this.showToast("Saving page move…")

    fetch(relocateUrl, {
      method: "PATCH",
      headers: this.requestHeaders(drag),
      body: body.toString(),
      credentials: "same-origin"
    })
      .then(async (response) => {
        if (!response.ok) throw new Error(await this.responseError(response))

        this.showToast("Page moved.")
        window.location.reload()
      })
      .catch((error) => {
        this.relocationFailed(drag, error.message || "Unable to move page.")
      })
  }

  relocationFailed(drag, message, { reload = true } = {}) {
    this.restoreOriginalPosition(drag)
    drag.item.classList.remove("generated-builder__toc-item--pending")
    drag.item.classList.add("generated-builder__toc-item--error")
    drag.item.removeAttribute("aria-busy")
    this.setListState(drag.sourceList, "error")
    this.setListState(drag.destinationList, "error")
    this.showToast(message, "alert")

    if (reload) window.setTimeout(() => window.location.reload(), 1200)
  }

  restoreOriginalPosition(drag) {
    if (!drag.sourceList?.isConnected || !drag.item) return

    if (drag.sourceNextSibling?.parentElement === drag.sourceList) {
      drag.sourceList.insertBefore(drag.item, drag.sourceNextSibling)
      return
    }

    const items = this.directItems(drag.sourceList).filter((item) => item !== drag.item)
    const reference = items[drag.sourceIndex]
    if (reference) {
      drag.sourceList.insertBefore(drag.item, reference)
    } else {
      drag.sourceList.append(drag.item)
    }
  }

  cleanupDrag(drag) {
    drag.item?.classList.remove("generated-builder__toc-item--dragging")
    this.clearDropTarget(drag)
    if (this.constructor.activeDrag === drag) this.constructor.activeDrag = null
  }

  dropAllowed(drag, destinationContainer, destinationList) {
    if (destinationList === drag.sourceList) return true
    if (!destinationContainer.logicalId || !destinationContainer.kind) return false
    if (!drag.sourceContainer.logicalId || !drag.sourceContainer.kind) return false
    if (drag.itemKind === "group" && destinationContainer.kind === "group") return false
    return true
  }

  itemKind(item) {
    if (item.dataset.segmentKind) return item.dataset.segmentKind
    return item.classList.contains("generated-builder__toc-item--group") ? "group" : "page"
  }

  containerMetadata(list) {
    return {
      logicalId: list.dataset.containerLogicalId || "",
      kind: list.dataset.containerKind || "",
      label: list.dataset.containerLabel || "group",
      packetLogicalId: list.dataset.packetLogicalId || "",
      groupPlacementId: list.dataset.groupPlacementId || "",
      sharedPacketCount: Number.parseInt(list.dataset.sharedPacketCount || "0", 10)
    }
  }

  sharedMoveConfirmation(sourceContainer, destinationContainer) {
    const messages = []

    if (sourceContainer.kind === "group" && sourceContainer.sharedPacketCount > 1) {
      messages.push(`remove it from ${sourceContainer.sharedPacketCount} packets using ${sourceContainer.label}`)
    }

    if (destinationContainer.kind === "group" && destinationContainer.sharedPacketCount > 1) {
      messages.push(`add it to ${destinationContainer.sharedPacketCount} packets using ${destinationContainer.label}`)
    }

    if (messages.length === 0) return ""

    return `This shared-group move will ${messages.join(" and ")}. Continue?`
  }

  directItems(list) {
    return Array.from(list.children).filter((item) => item.matches("[data-segment-id]"))
  }

  dropReferenceRect(item) {
    const row = item.querySelector(":scope > .generated-builder__toc-entry > .generated-builder__toc-row")
    return (row || item).getBoundingClientRect()
  }

  ownItemFrom(event) {
    const item = event.target.closest("[data-segment-id]")
    if (!item) return null

    return item.closest("[data-generated-segments-root]") === this.element ? item : null
  }

  ownListFrom(event) {
    const list = event.target.closest("[data-generated-segments-target~='list']")
    if (!list) return null

    return list.closest("[data-generated-segments-root]") === this.element ? list : null
  }

  markDropTarget(drag, list) {
    if (drag.markedList === list) return
    this.clearDropTarget(drag)
    drag.markedList = list
    list.classList.add("generated-builder__toc-body--drop-target")
    list.dataset.dragState = "target"
  }

  clearDropTarget(drag) {
    if (!drag.markedList) return
    drag.markedList.classList.remove("generated-builder__toc-body--drop-target")
    if (drag.markedList.dataset.dragState === "target") delete drag.markedList.dataset.dragState
    drag.markedList = null
  }

  setListState(list, state) {
    if (!list) return
    if (state) {
      list.dataset.dragState = state
    } else {
      delete list.dataset.dragState
    }
  }

  relocateUrlFor(drag) {
    return drag.destinationList.dataset.relocateUrl ||
      drag.sourceList.dataset.relocateUrl ||
      this.valueFromControllerTree(drag.destinationController, "generatedSegmentsRelocateUrlValue") ||
      this.valueFromControllerTree(drag.sourceController, "generatedSegmentsRelocateUrlValue")
  }

  requestHeaders(drag = null) {
    const csrfToken = this.valueFromControllerTree(drag?.destinationController || this, "generatedSegmentsCsrfTokenValue") ||
      this.valueFromControllerTree(drag?.sourceController, "generatedSegmentsCsrfTokenValue")

    return {
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
      "X-CSRF-Token": csrfToken || ""
    }
  }

  valueFromControllerTree(controller, dataAttribute) {
    let root = controller?.element
    while (root) {
      const value = root.dataset[dataAttribute]
      if (value) return value
      root = root.parentElement?.closest("[data-generated-segments-root]")
    }
    return ""
  }

  async responseError(response) {
    const fallback = "Unable to move page."

    try {
      const contentType = response.headers.get("content-type") || ""
      if (contentType.includes("application/json")) {
        const payload = await response.json()
        return payload.error || payload.message || fallback
      }

      if (contentType.includes("text/plain")) {
        const text = await response.text()
        return text.trim() || fallback
      }

      return fallback
    } catch (_error) {
      return fallback
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

export default GeneratedSegmentsController
