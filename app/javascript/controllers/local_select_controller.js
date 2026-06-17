import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "menu", "select"]
  static values = {
    emptyLabel: { type: String, default: "Choose an option..." },
    limit: { type: Number, default: 20 }
  }

  connect() {
    this.closeTimer = null
    this.menuId = this.hasMenuTarget && this.menuTarget.id
      ? this.menuTarget.id
      : `local-select-menu-${Math.random().toString(36).slice(2)}`

    this.boundOutsideClick = this.handleOutsideClick.bind(this)
    this.boundFocusOut = this.handleFocusOut.bind(this)

    document.addEventListener("click", this.boundOutsideClick)
    this.element.addEventListener("focusout", this.boundFocusOut)

    this.setupAccessibility()
    this.syncInputFromSelect()
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    this.element.removeEventListener("focusout", this.boundFocusOut)
    this.clearCloseTimer()
  }

  search() {
    if (!this.hasInputTarget || !this.hasMenuTarget || !this.hasSelectTarget) return

    this.clearCloseTimer()

    const query = this.inputTarget.value.trim().toLowerCase()
    if (!query) this.selectValue("")

    const options = this.options().filter((option) => {
      if (!option.value) return !query
      return option.searchText.includes(query)
    }).slice(0, this.limitValue)

    this.render(options)
  }

  choose(event) {
    this.selectOption(event.currentTarget)
  }

  syncFromSelect() {
    this.syncInputFromSelect()
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
      case "Enter":
        event.preventDefault()
        this.selectOption(button)
        break
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
      this.syncInputFromSelect()
      this.hideMenu()
    }, 0)
  }

  handleOutsideClick(event) {
    if (this.element.contains(event.target)) return
    this.syncInputFromSelect()
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
      button.dataset.value = option.value
      button.dataset.label = option.label
      button.setAttribute("role", "option")
      button.setAttribute("aria-selected", "false")
      button.addEventListener("click", (event) => this.choose(event))
      button.addEventListener("keydown", (event) => this.handleOptionKeydown(event))
      button.addEventListener("mousedown", (event) => this.handleOptionMouseDown(event))
      button.addEventListener("focus", () => this.markOptionActive(button))

      const title = document.createElement("span")
      title.className = "calendar-item-form__autocomplete-option-title"
      title.textContent = option.label || this.emptyLabelValue

      button.appendChild(title)
      this.menuTarget.appendChild(button)
    })

    this.menuTarget.hidden = false
    this.updateExpandedState(true)
  }

  hideMenu() {
    if (!this.hasMenuTarget) return

    this.clearCloseTimer()
    this.menuTarget.hidden = true
    this.menuTarget.innerHTML = ""
    this.updateExpandedState(false)
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

  syncInputFromSelect() {
    if (!this.hasInputTarget || !this.hasSelectTarget) return

    const selectedOption = this.selectTarget.selectedOptions[0]
    this.inputTarget.value = selectedOption && selectedOption.value ? selectedOption.textContent.trim() : ""
  }

  selectOption(button) {
    if (!(button instanceof HTMLButtonElement)) return

    this.selectValue(button.dataset.value || "")
    this.syncInputFromSelect()
    this.hideMenu()
    this.inputTarget.focus()
  }

  selectValue(value) {
    if (!this.hasSelectTarget) return

    if (this.selectTarget.value === value) return

    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  options() {
    if (!this.hasSelectTarget) return []

    return Array.from(this.selectTarget.options).map((option) => ({
      value: option.value,
      label: option.textContent.trim(),
      searchText: option.textContent.trim().toLowerCase()
    }))
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
}
