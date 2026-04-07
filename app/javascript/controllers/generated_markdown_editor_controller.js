import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "dialog", "overlay", "openButton"]

  connect() {
    this.selectionRanges = new WeakMap()

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

    this.syncValueFrom(this.overlayTarget)
  }

  syncFromSource() {
    if (!this.hasSourceTarget) return

    this.syncValueFrom(this.sourceTarget)
  }

  format(event) {
    event.preventDefault()

    const target = this.editableTarget()
    if (!target) return

    const format = event.currentTarget.dataset.markdownFormat
    if (!format) return

    switch (format) {
      case "bold":
        this.wrapSelection(target, "**", "**", "Bold text")
        break
      case "italic":
        this.wrapSelection(target, "*", "*", "Italic text")
        break
      case "headline":
        this.prefixSelectedLines(target, "### ", "Headline")
        break
      case "link":
        this.insertLink(target)
        break
      default:
        return
    }

    this.syncValueFrom(target)
    target.focus()
  }

  preserveSelection(event) {
    event.preventDefault()
  }

  rememberSelection(event) {
    const target = event.currentTarget
    const start = target.selectionStart ?? 0
    const end = target.selectionEnd ?? start

    this.selectionRanges.set(target, { start, end })
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

  syncValueFrom(target) {
    const value = target.value

    if (this.hasOverlayTarget && target !== this.overlayTarget && this.overlayTarget.value !== value) {
      this.overlayTarget.value = value
    }

    if (this.hasSourceTarget && target !== this.sourceTarget && this.sourceTarget.value !== value) {
      this.sourceTarget.value = value
      this.sourceTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  editableTarget() {
    if (this.isDialogOpen() && this.hasOverlayTarget) {
      return this.overlayTarget
    }

    return this.hasSourceTarget ? this.sourceTarget : null
  }

  wrapSelection(target, prefix, suffix, placeholder) {
    const { start: selectionStart, end: selectionEnd } = this.selectionRangeFor(target)
    const selectedText = target.value.slice(selectionStart, selectionEnd) || placeholder
    const replacement = `${prefix}${selectedText}${suffix}`
    const cursorStart = selectionStart + prefix.length
    const cursorEnd = cursorStart + selectedText.length

    this.replaceSelection(target, replacement, cursorStart, cursorEnd)
  }

  prefixSelectedLines(target, prefix, placeholder) {
    const { start: selectionStart, end: selectionEnd } = this.selectionRangeFor(target)
    const value = target.value
    const lineStart = value.lastIndexOf("\n", Math.max(selectionStart - 1, 0)) + 1
    const lineEndIndex = value.indexOf("\n", selectionEnd)
    const lineEnd = lineEndIndex === -1 ? value.length : lineEndIndex
    const selectedBlock = value.slice(lineStart, lineEnd)
    const block = selectedBlock.trim().length > 0 ? selectedBlock : placeholder
    const prefixedBlock = block
      .split("\n")
      .map((line) => (line.trim().length > 0 ? `${prefix}${line}` : line))
      .join("\n")

    target.value = `${value.slice(0, lineStart)}${prefixedBlock}${value.slice(lineEnd)}`
    const newSelectionEnd = lineStart + prefixedBlock.length
    target.setSelectionRange(lineStart, newSelectionEnd)
    this.selectionRanges.set(target, { start: lineStart, end: newSelectionEnd })
  }

  insertLink(target) {
    const { start: selectionStart, end: selectionEnd } = this.selectionRangeFor(target)
    const selectedText = target.value.slice(selectionStart, selectionEnd) || "Link text"
    const url = window.prompt("Enter a URL", "https://")
    if (url === null) return

    const normalizedUrl = url.trim()
    if (normalizedUrl.length === 0) return

    const replacement = `[${selectedText}](${normalizedUrl})`
    const cursorStart = selectionStart + 1
    const cursorEnd = cursorStart + selectedText.length

    this.replaceSelection(target, replacement, cursorStart, cursorEnd)
  }

  replaceSelection(target, replacement, selectionStart, selectionEnd) {
    const { start, end } = this.selectionRangeFor(target)
    const value = target.value

    target.value = `${value.slice(0, start)}${replacement}${value.slice(end)}`
    target.setSelectionRange(selectionStart, selectionEnd)
    this.selectionRanges.set(target, { start: selectionStart, end: selectionEnd })
  }

  selectionRangeFor(target) {
    const savedRange = this.selectionRanges.get(target)
    if (savedRange && document.activeElement !== target) {
      return savedRange
    }

    const start = target.selectionStart ?? savedRange?.start ?? 0
    const end = target.selectionEnd ?? savedRange?.end ?? start
    return { start, end }
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
