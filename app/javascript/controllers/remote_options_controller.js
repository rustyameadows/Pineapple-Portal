import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden"]
  static values = {
    url: String,
    minChars: { type: Number, default: 0 }
  }

  connect() {
    this.abortController = null
    this.optionMap = new Map()
    this.handleInputBound = this.handleInput.bind(this)
    this.handleChangeBound = this.handleChange.bind(this)
    this.handleFocusBound = this.handleFocus.bind(this)
    this.inputEl = this.resolveInputElement()
    if (!this.inputEl) return

    this.ensureDatalist()
    this.inputEl.addEventListener("input", this.handleInputBound)
    this.inputEl.addEventListener("change", this.handleChangeBound)
    this.inputEl.addEventListener("focus", this.handleFocusBound)
  }

  disconnect() {
    if (this.inputEl) {
      this.inputEl.removeEventListener("input", this.handleInputBound)
      this.inputEl.removeEventListener("change", this.handleChangeBound)
      this.inputEl.removeEventListener("focus", this.handleFocusBound)
    }
    if (this.abortController) this.abortController.abort()
  }

  handleFocus() {
    this.fetchOptions(this.inputEl.value)
  }

  handleInput() {
    if (!this.inputEl) return
    this.fetchOptions(this.inputEl.value)
    this.syncHiddenField({ strict: true })
  }

  handleChange() {
    this.syncHiddenField()
  }

  resolveInputElement() {
    if (this.hasInputTarget) return this.inputTarget
    return this.element instanceof HTMLInputElement ? this.element : null
  }

  ensureDatalist() {
    if (this.inputEl.list) {
      this.datalistEl = this.inputEl.list
      return
    }

    const generatedId = `remote-options-${Math.random().toString(36).slice(2)}`
    this.datalistEl = document.createElement("datalist")
    this.datalistEl.id = generatedId
    this.inputEl.setAttribute("list", generatedId)
    if (this.element instanceof HTMLInputElement) {
      this.inputEl.parentElement?.appendChild(this.datalistEl)
    } else {
      this.element.appendChild(this.datalistEl)
    }
  }

  fetchOptions(rawQuery) {
    if (!this.hasUrlValue || !this.datalistEl) return

    const query = (rawQuery || "").trim()
    if (query.length < this.minCharsValue) {
      this.clearOptions()
      return
    }

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)
    url.searchParams.set("limit", "20")

    fetch(url.toString(), {
      headers: { Accept: "application/json" },
      signal: this.abortController.signal
    })
      .then((response) => (response.ok ? response.json() : { options: [] }))
      .then((payload) => this.renderOptions(Array.isArray(payload.options) ? payload.options : []))
      .catch((error) => {
        if (error.name !== "AbortError") this.clearOptions()
      })
  }

  renderOptions(options) {
    this.optionMap = new Map()
    this.datalistEl.innerHTML = ""

    options.forEach((option) => {
      if (!option || !option.name) return
      if (!this.optionMap.has(option.name)) this.optionMap.set(option.name, String(option.id))

      const el = document.createElement("option")
      el.value = option.name
      const status = option.is_active_on_event ? "Already in this event" : "Global"
      el.label = `${status} · used ${option.usage_count || 0} times`
      this.datalistEl.appendChild(el)
    })
  }

  clearOptions() {
    this.optionMap = new Map()
    if (this.datalistEl) this.datalistEl.innerHTML = ""
    this.syncHiddenField()
  }

  syncHiddenField({ strict = false } = {}) {
    if (!this.hasHiddenTarget || !this.inputEl) return
    const value = this.inputEl.value || ""
    const selectedId = this.optionMap.get(value) || ""
    if (strict && selectedId === "") {
      this.hiddenTarget.value = ""
      return
    }
    this.hiddenTarget.value = selectedId
  }
}
