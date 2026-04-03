import { Controller } from "@hotwired/stimulus"
import { performDirectUpload } from "controllers/shared/direct_upload"

export default class extends Controller {
  static targets = [
    "file",
    "status",
    "submit",
    "storageUri",
    "checksum",
    "sizeBytes",
    "contentType",
    "logicalId",
    "title"
  ]

  connect() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  async upload() {
    const file = this.hasFileTarget ? this.fileTarget.files?.[0] : null
    if (!file) {
      this.reset()
      return
    }

    this.setStatus("Preparing upload…")
    if (this.hasSubmitTarget) this.submitTarget.disabled = true

    try {
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content || ""
      const { presignData, checksum } = await performDirectUpload({
        scope: "generated_packet_upload",
        presignUrl: this.element.dataset.presignUrl,
        file,
        csrfToken,
        onProgress: () => this.setStatus("Uploading PDF…")
      })

      if (this.hasStorageUriTarget) this.storageUriTarget.value = presignData.storage_uri
      if (this.hasChecksumTarget) this.checksumTarget.value = checksum
      if (this.hasSizeBytesTarget) this.sizeBytesTarget.value = file.size
      if (this.hasContentTypeTarget) this.contentTypeTarget.value = presignData.content_type
      if (this.hasLogicalIdTarget) this.logicalIdTarget.value = presignData.logical_id
      if (this.hasTitleTarget && !this.titleTarget.value) this.titleTarget.value = file.name
      if (this.hasSubmitTarget) this.submitTarget.disabled = false

      this.setStatus("Upload ready. Add the PDF to place it in this packet.")
    } catch (error) {
      this.setStatus(error.message || "Upload failed.")
    }
  }

  reset() {
    this.setStatus("Choose a PDF to upload directly into this packet.")
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
