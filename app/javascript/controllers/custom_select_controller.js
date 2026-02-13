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
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    this.abortController?.abort()
  }

  search() {
    if (!this.hasInputTarget || !this.hasMenuTarget || !this.hasUrlValue) return

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
    const button = event.currentTarget
    const value = button.dataset.value || ""
    const globalId = button.dataset.globalId || ""
    this.inputTarget.value = value
    await this.ensureEventLink(globalId, value)
    this.hideMenu()
    this.inputTarget.focus()
  }

  deferClose() {
    setTimeout(() => this.hideMenu(), 120)
  }

  focusFirst(event) {
    if (event.key !== "ArrowDown" || this.menuTarget.hidden) return
    const first = this.menuTarget.querySelector("button")
    if (!first) return
    event.preventDefault()
    first.focus()
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

    options.forEach((option) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "calendar-item-form__autocomplete-option"
      button.dataset.value = option.name
      button.dataset.globalId = String(option.id || "")
      button.setAttribute("role", "option")
      button.addEventListener("click", (event) => this.choose(event))

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
  }

  hideMenu() {
    if (!this.hasMenuTarget) return
    this.menuTarget.hidden = true
    this.menuTarget.innerHTML = ""
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
}
