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

  confirmHighRisk(event) {
    if (!this.hasHighRiskAcknowledgementTarget) return
    if (this.highRiskAcknowledgementTarget.checked) return

    event.preventDefault()
  }
}
