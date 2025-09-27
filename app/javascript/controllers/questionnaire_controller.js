import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "saveButton"]

  isSaving = false

  async saveAll(event) {
    event.preventDefault()

    if (this.isSaving) return
    this.isSaving = true

    const button = this.hasSaveButtonTarget ? this.saveButtonTarget : null
    const originalText = button ? button.textContent : null

    if (button) {
      button.disabled = true
      button.textContent = "Saving..."
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      for (const form of this.formTargets) {
        const formData = new FormData(form)
        await fetch(form.action, {
          method: form.method.toUpperCase(),
          headers: {
            "Accept": "text/vnd.turbo-stream.html, text/html",
            ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
          },
          body: formData,
          credentials: "same-origin"
        })
      }

      if (button) {
        button.textContent = "Responses saved"
        setTimeout(() => {
          button.textContent = originalText
          button.disabled = false
        }, 2500)
      }
    } catch (error) {
      console.error("Failed to save questionnaire responses", error)
      if (button) {
        button.textContent = "Save all responses"
        button.disabled = false
      }
      alert("We couldn't save all responses. Please try again.")
    } finally {
      this.isSaving = false
    }
  }
}
