import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    iso: String,
    format: {
      type: String,
      default: "long"
    }
  }

  connect() {
    this.render()
  }

  render() {
    if (!this.hasIsoValue) return

    const date = new Date(this.isoValue)
    if (Number.isNaN(date.getTime())) return

    this.element.textContent = this.formatter().format(date)
  }

  formatter() {
    switch (this.formatValue) {
      case "compact":
        return new Intl.DateTimeFormat(undefined, {
          month: "short",
          day: "2-digit",
          hour: "numeric",
          minute: "2-digit"
        })
      case "short":
        return new Intl.DateTimeFormat(undefined, {
          month: "short",
          day: "2-digit",
          year: "numeric",
          hour: "numeric",
          minute: "2-digit"
        })
      default:
        return new Intl.DateTimeFormat(undefined, {
          month: "long",
          day: "2-digit",
          year: "numeric",
          hour: "numeric",
          minute: "2-digit"
        })
    }
  }
}
