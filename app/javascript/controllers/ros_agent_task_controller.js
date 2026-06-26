import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recommendedAnswer", "highRiskAcknowledgement"]

  useRecommendedAnswers() {
    this.recommendedAnswerTargets.forEach((field) => {
      if (field.type === "radio" || field.type === "checkbox") {
        field.checked = true
      } else {
        field.value = field.dataset.recommendedValue || field.value
      }
    })
  }

  selectCustomAnswer(event) {
    const radioId = event.currentTarget.dataset.customAnswerRadioId
    if (!radioId) return

    const radio = document.getElementById(radioId)
    if (radio) radio.checked = true
  }

  confirmHighRisk(event) {
    if (!this.hasHighRiskAcknowledgementTarget) return
    if (this.highRiskAcknowledgementTarget.checked) return

    event.preventDefault()
  }
}
