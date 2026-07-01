import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recommendedAnswer", "highRiskAcknowledgement", "refinementPrompt", "refinementSubmit"]

  connect() {
    this.updateRefinementSubmit()
  }

  refinementPromptTargetConnected() {
    this.updateRefinementSubmit()
  }

  refinementSubmitTargetConnected() {
    this.updateRefinementSubmit()
  }

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

  updateRefinementSubmit() {
    if (!this.hasRefinementPromptTarget || !this.hasRefinementSubmitTarget) return

    this.refinementSubmitTarget.disabled = this.refinementPromptTarget.value.trim().length === 0
  }

  confirmHighRisk(event) {
    if (!this.hasHighRiskAcknowledgementTarget) return
    if (this.highRiskAcknowledgementTarget.checked) return

    event.preventDefault()
  }
}
