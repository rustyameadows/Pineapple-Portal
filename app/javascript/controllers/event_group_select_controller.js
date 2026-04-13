import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "customField", "customInput"]
  static values = {
    newOption: { type: String, default: "__new__" }
  }

  connect() {
    this.sync()
  }

  sync() {
    if (!this.hasSelectTarget || !this.hasCustomFieldTarget || !this.hasCustomInputTarget) return

    const showCustomField = this.selectTarget.value === this.newOptionValue

    this.customFieldTarget.hidden = !showCustomField
    this.customInputTarget.disabled = !showCustomField
    this.customInputTarget.required = showCustomField
  }
}
