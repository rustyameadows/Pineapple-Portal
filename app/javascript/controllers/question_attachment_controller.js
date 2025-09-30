import { Controller } from "@hotwired/stimulus"

const checksumHex = async (file) => {
  const buffer = await file.arrayBuffer()
  const digest = await crypto.subtle.digest("SHA-256", buffer)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
}

export default class extends Controller {
  static targets = [
    "attachmentList",
    "dropzone",
    "status",
    "fileInput",
    "emptyState",
    "shell"
  ]

  static values = {
    presignUrl: String,
    attachmentsPath: String,
    entityType: String,
    entityId: Number
  }

  isUploading = false

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    this.updateEmptyState()
  }

  dragOver(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("is-over")
    if (this.hasShellTarget) {
      this.shellTarget.classList.add("is-over")
    }
  }

  dragLeave(event) {
    event.preventDefault()
    if (!this.element.contains(event.relatedTarget)) {
      this.dropzoneTarget.classList.remove("is-over")
      if (this.hasShellTarget) {
        this.shellTarget.classList.remove("is-over")
      }
    }
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("is-over")
    if (this.hasShellTarget) {
      this.shellTarget.classList.remove("is-over")
    }
    const files = Array.from(event.dataTransfer.files || [])
    this.handleFiles(files)
  }

  handleFileSelection(event) {
    const files = Array.from(event.target.files || [])
    event.target.value = ""
    this.handleFiles(files)
  }

  openFileDialog(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }

  async handleFiles(files) {
    if (!files.length || this.isUploading) return

    for (const file of files) {
      await this.uploadFile(file)
    }
  }

  async uploadFile(file) {
    this.isUploading = true
    this.dispatchEvent("question-attachment:start")

    try {
      this.setStatus(`Preparing ${file.name}...`)
      const presignResponse = await fetch(this.presignUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ filename: file.name, content_type: file.type || "application/octet-stream" })
      })

      if (!presignResponse.ok) {
        throw new Error("Could not prepare upload")
      }

      const presignData = await presignResponse.json()

      this.setStatus(`Uploading ${file.name}...`)
      const uploadResponse = await fetch(presignData.upload_url, {
        method: "PUT",
        headers: { "Content-Type": presignData.content_type },
        body: file
      })

      if (!uploadResponse.ok) {
        throw new Error("Upload failed")
      }

      const checksum = await checksumHex(file)

      const formData = new FormData()
      formData.append("attachment[entity_type]", this.entityTypeValue)
      formData.append("attachment[entity_id]", this.entityIdValue)
      formData.append("attachment[context]", "answer")
      formData.append("attachment[file_upload_title]", file.name)
      formData.append("attachment[file_upload_storage_uri]", presignData.storage_uri)
      formData.append("attachment[file_upload_checksum]", checksum)
      formData.append("attachment[file_upload_size_bytes]", file.size)
      formData.append("attachment[file_upload_content_type]", presignData.content_type)
      formData.append("attachment[file_upload_logical_id]", presignData.logical_id)

      this.setStatus("Saving attachment...")
      const response = await fetch(this.attachmentsPathValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "X-Requested-With": "XMLHttpRequest"
        },
        body: formData,
        credentials: "same-origin"
      })

      let payload
      try {
        payload = await response.clone().json()
      } catch (parseError) {
        console.error("Failed to parse attachment response", parseError)
        throw new Error("Could not save attachment")
      }

      if (!response.ok) {
        throw new Error(payload.error || "Could not save attachment")
      }

      if (payload.html) {
        this.attachmentListTarget.insertAdjacentHTML("beforeend", payload.html)
        this.updateEmptyState()
      }

      this.setStatus(`${file.name} attached.`)
      setTimeout(() => this.clearStatus(), 2500)
    } catch (error) {
      console.error(error)
      this.setStatus(error.message || "Upload failed. Please try again.")
    } finally {
      this.isUploading = false
      this.dispatchEvent("question-attachment:finish")
    }
  }

  updateEmptyState() {
    if (!this.hasEmptyStateTarget) return
    const hasChips = this.attachmentListTarget.querySelectorAll("[data-attachment-chip]").length > 0
    this.emptyStateTarget.hidden = hasChips
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }

  clearStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = ""
    }
  }

  dispatchEvent(name) {
    const event = new CustomEvent(name, { bubbles: true })
    this.element.dispatchEvent(event)
  }
}
