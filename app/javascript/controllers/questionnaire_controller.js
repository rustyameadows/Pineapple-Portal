import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "saveButton"]

  isSaving = false
  pendingUploads = 0

  connect() {
    this.handleAttachmentStart = this.handleAttachmentStart.bind(this)
    this.handleAttachmentFinish = this.handleAttachmentFinish.bind(this)
    this.element.addEventListener("question-attachment:start", this.handleAttachmentStart)
    this.element.addEventListener("question-attachment:finish", this.handleAttachmentFinish)
  }

  disconnect() {
    this.element.removeEventListener("question-attachment:start", this.handleAttachmentStart)
    this.element.removeEventListener("question-attachment:finish", this.handleAttachmentFinish)
  }

  async saveAll(event) {
    event.preventDefault()

    if (this.isSaving || this.pendingUploads > 0) {
      if (this.pendingUploads > 0) {
        alert("Please wait for file uploads to finish before saving.")
      }
      return
    }
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
      if (this.pendingUploads === 0) {
        this.enableSaveButton()
      }
    }
  }

  handleAttachmentStart() {
    this.pendingUploads += 1
    this.disableSaveButton()
  }

  handleAttachmentFinish() {
    this.pendingUploads = Math.max(0, this.pendingUploads - 1)
    if (!this.isSaving && this.pendingUploads === 0) {
      this.enableSaveButton()
    }
  }

  disableSaveButton() {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = true
    }
  }

  enableSaveButton() {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = false
    }
  }
}
