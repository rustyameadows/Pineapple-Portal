import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu"]
  static values = {
    url: String,
    linkUrl: String,
    linkKind: String,
    minChars: { type: Number, default: 0 }
  }

  connect() {
    this.abortController = null
    this.closeTimer = null
    this.menuId = this.hasMenuTarget && this.menuTarget.id
      ? this.menuTarget.id
      : `custom-select-menu-${Math.random().toString(36).slice(2)}`

    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    this.boundFocusOut = this.handleFocusOut.bind(this)

    document.addEventListener("click", this.boundOutsideClick)
    this.element.addEventListener("focusout", this.boundFocusOut)

    this.setupAccessibility()
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    this.element.removeEventListener("focusout", this.boundFocusOut)
    this.clearCloseTimer()
    this.abortController?.abort()
  }

  search() {
    if (!this.hasInputTarget || !this.hasMenuTarget || !this.hasUrlValue) return

    this.clearCloseTimer()

    const query = this.inputTarget.value.trim()
    if (query.length < this.minCharsValue) {
      this.hideMenu()
      return
    }

    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    url.searchParams.set("limit", "8")

    fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })
      .then((response) => (response.ok ? response.json() : { options: [] }))
      .then((payload) => {
        const options = Array.isArray(payload.options) ? payload.options : []
        this.render(options)
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.hideMenu()
      })
  }

  async choose(event) {
    await this.selectOption(event.currentTarget)
  }

  handleInputKeydown(event) {
    if (this.menuTarget.hidden) return

    const firstOption = this.firstOption()
    const lastOption = this.lastOption()

    switch (event.key) {
      case "ArrowDown":
        if (!firstOption) return
        event.preventDefault()
        firstOption.focus()
        break
      case "ArrowUp":
        if (!lastOption) return
        event.preventDefault()
        lastOption.focus()
        break
      case "Tab":
        if (event.shiftKey || !firstOption) return
        event.preventDefault()
        firstOption.focus()
        break
      case "Enter":
        if (!firstOption) return
        event.preventDefault()
        this.selectOption(firstOption)
        break
      case "Escape":
        event.preventDefault()
        this.hideMenu()
        break
      default:
        break
    }
  }

  handleOptionKeydown(event) {
    const button = event.currentTarget
    if (!(button instanceof HTMLButtonElement)) return

    switch (event.key) {
      case "ArrowDown": {
        const next = this.adjacentOption(button, 1)
        if (!next) return
        event.preventDefault()
        next.focus()
        break
      }
      case "ArrowUp": {
        event.preventDefault()

        const previous = this.adjacentOption(button, -1)
        if (previous) {
          previous.focus()
        } else {
          this.inputTarget.focus()
        }
        break
      }
      case "Escape":
        event.preventDefault()
        this.hideMenu()
        this.inputTarget.focus()
        break
      default:
        break
    }
  }

  handleOptionMouseDown(event) {
    event.preventDefault()
  }

  handleFocusOut(event) {
    this.clearCloseTimer()

    const nextTarget = event.relatedTarget
    if (nextTarget instanceof Node && this.element.contains(nextTarget)) return

    this.closeTimer = window.setTimeout(() => {
      const activeElement = document.activeElement
      if (activeElement instanceof Node && this.element.contains(activeElement)) return
      this.hideMenu()
    }, 0)
  }

  handleOutsideClick(event) {
    if (this.element.contains(event.target)) return
    this.hideMenu()
  }

  render(options) {
    if (!options.length) {
      this.hideMenu()
      return
    }

    this.menuTarget.innerHTML = ""

    options.forEach((option, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.id = `${this.menuId}-option-${index}`
      button.className = "calendar-item-form__autocomplete-option"
      button.dataset.value = option.name
      button.dataset.globalId = String(option.id || "")
      button.setAttribute("role", "option")
      button.setAttribute("aria-selected", "false")
      button.addEventListener("click", (event) => this.choose(event))
      button.addEventListener("keydown", (event) => this.handleOptionKeydown(event))
      button.addEventListener("mousedown", (event) => this.handleOptionMouseDown(event))
      button.addEventListener("focus", () => this.markOptionActive(button))

      const title = document.createElement("span")
      title.className = "calendar-item-form__autocomplete-option-title"
      title.textContent = option.name

      const meta = document.createElement("span")
      meta.className = "calendar-item-form__autocomplete-option-meta"
      meta.textContent = option.is_active_on_event ? "Already on this event" : "Global library"

      button.appendChild(title)
      button.appendChild(meta)
      this.menuTarget.appendChild(button)
    })

    this.menuTarget.hidden = false
    this.updateExpandedState(true)
  }

  hideMenu() {
    if (!this.hasMenuTarget) return

    this.clearCloseTimer()
    this.abortController?.abort()
    this.menuTarget.hidden = true
    this.menuTarget.innerHTML = ""
    this.updateExpandedState(false)
  }

  async ensureEventLink(globalId, name) {
    if (!this.hasLinkUrlValue) return

    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    const idKey = this.linkKindValue === "venue" ? "global_venue_id" : "global_vendor_id"
    const payload = globalId ? { [idKey]: globalId, ...(name ? { name } : {}) } : { name }

    try {
      await fetch(this.linkUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
        },
        body: JSON.stringify(payload)
      })
    } catch (_) {
      // Non-blocking: keep user input even if linking call fails.
    }
  }

  setupAccessibility() {
    if (!this.hasInputTarget || !this.hasMenuTarget) return

    this.menuTarget.id = this.menuId
    this.menuTarget.setAttribute("role", "listbox")

    this.inputTarget.setAttribute("role", "combobox")
    this.inputTarget.setAttribute("aria-autocomplete", "list")
    this.inputTarget.setAttribute("aria-controls", this.menuId)
    this.updateExpandedState(!this.menuTarget.hidden)
  }

  updateExpandedState(isExpanded) {
    if (!this.hasInputTarget) return
    this.inputTarget.setAttribute("aria-expanded", isExpanded ? "true" : "false")
  }

  firstOption() {
    return this.menuTarget.querySelector("button")
  }

  lastOption() {
    const options = this.optionButtons()
    return options[options.length - 1] || null
  }

  adjacentOption(button, offset) {
    const options = this.optionButtons()
    const index = options.indexOf(button)
    if (index === -1) return null

    return options[index + offset] || null
  }

  optionButtons() {
    return Array.from(this.menuTarget.querySelectorAll("button"))
  }

  markOptionActive(activeButton) {
    this.optionButtons().forEach((button) => {
      button.setAttribute("aria-selected", button === activeButton ? "true" : "false")
    })
  }

  clearCloseTimer() {
    if (!this.closeTimer) return

    window.clearTimeout(this.closeTimer)
    this.closeTimer = null
  }

  async selectOption(button) {
    if (!(button instanceof HTMLButtonElement)) return

    const value = button.dataset.value || ""
    const globalId = button.dataset.globalId || ""

    this.inputTarget.value = value
    await this.ensureEventLink(globalId, value)
    this.hideMenu()
    this.inputTarget.focus()
  }
}
