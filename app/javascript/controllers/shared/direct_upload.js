const FAILURE_REPORT_PATH = "/upload_failures"
const RESPONSE_TEXT_LIMIT = 400

const truncate = (value, limit = RESPONSE_TEXT_LIMIT) => {
  const text = value == null ? "" : String(value).trim()
  if (!text) return ""
  if (text.length <= limit) return text

  return `${text.slice(0, limit - 1)}…`
}

const withOrigin = (value) => {
  try {
    return new URL(value, window.location.origin)
  } catch (_error) {
    return null
  }
}

const responseDetail = (responseText) => {
  const detail = truncate(responseText, 160)
  return detail ? ` Details: ${detail}` : ""
}

const readResponseText = async (response) => {
  try {
    return truncate(await response.text())
  } catch (_error) {
    return ""
  }
}

const requestPresign = async ({ presignUrl, filename, contentType, logicalId, csrfToken }) => {
  const requestBody = {
    filename,
    content_type: contentType || "application/octet-stream"
  }

  if (logicalId) requestBody.logical_id = logicalId

  let response

  try {
    response = await fetch(presignUrl, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken || ""
      },
      body: JSON.stringify(requestBody),
      credentials: "same-origin"
    })
  } catch (error) {
    throw buildUploadError({
      stage: "presign",
      message: "Could not prepare the upload. Check your connection and try again.",
      cause: error
    })
  }

  if (!response.ok) {
    throw buildUploadError({
      stage: "presign",
      status: response.status,
      responseText: await readResponseText(response)
    })
  }

  const responseText = await response.text()

  try {
    return JSON.parse(responseText)
  } catch (_error) {
    throw buildUploadError({
      stage: "presign",
      status: response.status,
      responseText,
      message: "Could not prepare the upload because Pineapple returned an unexpected response."
    })
  }
}

const uploadToStorage = ({ uploadUrl, file, contentType, onProgress }) => {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open("PUT", uploadUrl, true)

    if (contentType) {
      xhr.setRequestHeader("Content-Type", contentType)
    }

    xhr.upload.addEventListener("progress", (event) => {
      onProgress(event.loaded, event.total, event.lengthComputable)
    })

    xhr.addEventListener("load", () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve()
        return
      }

      reject(buildUploadError({
        stage: "storage_put",
        status: xhr.status || null,
        responseText: truncate(xhr.responseText)
      }))
    })

    xhr.addEventListener("error", () => {
      reject(buildUploadError({
        stage: "storage_put",
        status: xhr.status || 0,
        responseText: truncate(xhr.responseText)
      }))
    })

    xhr.addEventListener("abort", () => {
      reject(buildUploadError({
        stage: "storage_put",
        status: xhr.status || 0,
        message: "Upload to storage was cancelled before it completed."
      }))
    })

    xhr.send(file)
  })
}

export const checksumHex = async (file) => {
  const buffer = await file.arrayBuffer()
  const digest = await crypto.subtle.digest("SHA-256", buffer)
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("")
}

export const buildUploadError = ({ stage, status = null, responseText = "", message = null, cause = null }) => {
  const error = new Error(message || defaultUploadErrorMessage({ stage, status, responseText }))
  error.name = "DirectUploadError"
  error.stage = stage
  error.status = status
  error.responseText = truncate(responseText)
  if (cause) error.cause = cause
  return error
}

export const defaultUploadErrorMessage = ({ stage, status = null, responseText = "" }) => {
  switch (stage) {
    case "presign":
      if (status) return `Could not prepare the upload (HTTP ${status}).${responseDetail(responseText)}`
      return "Could not prepare the upload. Check your connection and try again."
    case "storage_put":
      if (status === 0 || status == null) {
        return "Upload to storage was blocked before it completed. This usually points to a storage CORS or network issue."
      }
      return `Upload to storage failed (HTTP ${status}).${responseDetail(responseText)}`
    case "metadata_save":
      if (status) return `The file uploaded, but saving it in Pineapple failed (HTTP ${status}).${responseDetail(responseText)}`
      return `The file uploaded, but saving it in Pineapple failed.${responseDetail(responseText)}`
    default:
      return `Upload failed.${responseDetail(responseText)}`
  }
}

export const extractEventIdFromPresignUrl = (presignUrl) => {
  const url = withOrigin(presignUrl)
  if (!url) return null

  const match = url.pathname.match(/\/events\/(\d+)\//)
  return match ? Number(match[1]) : null
}

export const reportUploadFailure = async ({
  csrfToken = "",
  scope,
  stage,
  presignUrl = null,
  storageUri = null,
  logicalId = null,
  status = null,
  responseText = "",
  message = "",
  extra = {}
}) => {
  const payload = {
    scope,
    stage,
    path: window.location.pathname,
    presign_url: presignUrl,
    event_id: extractEventIdFromPresignUrl(presignUrl),
    storage_uri: storageUri,
    logical_id: logicalId,
    status,
    response_text: truncate(responseText),
    message,
    user_agent: navigator.userAgent,
    ...extra
  }

  Object.keys(payload).forEach((key) => {
    if (payload[key] == null || payload[key] === "") delete payload[key]
  })

  try {
    await fetch(FAILURE_REPORT_PATH, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": csrfToken || ""
      },
      body: JSON.stringify(payload),
      credentials: "same-origin",
      keepalive: true
    })
  } catch (error) {
    console.error("Failed to report upload failure", error)
  }
}

export const reportUploadFailureForError = async ({
  error,
  csrfToken = "",
  scope,
  presignUrl = null,
  storageUri = null,
  logicalId = null,
  extra = {}
}) => {
  await reportUploadFailure({
    csrfToken,
    scope,
    stage: error?.stage || "unknown",
    presignUrl,
    storageUri,
    logicalId,
    status: error?.status,
    responseText: error?.responseText,
    message: error?.message,
    extra
  })
}

export const performDirectUpload = async ({
  scope,
  presignUrl,
  file,
  logicalId = null,
  csrfToken = "",
  onProgress = () => {}
}) => {
  let presignData = null

  try {
    presignData = await requestPresign({
      presignUrl,
      filename: file.name,
      contentType: file.type || "application/octet-stream",
      logicalId,
      csrfToken
    })

    await uploadToStorage({
      uploadUrl: presignData.upload_url,
      file,
      contentType: presignData.content_type,
      onProgress
    })

    return {
      presignData,
      checksum: await checksumHex(file)
    }
  } catch (error) {
    const uploadError = error?.stage ? error : buildUploadError({
      stage: presignData ? "storage_put" : "presign",
      message: error?.message || "Upload failed."
    })

    await reportUploadFailureForError({
      error: uploadError,
      csrfToken,
      scope,
      presignUrl,
      storageUri: presignData?.storage_uri,
      logicalId: presignData?.logical_id || logicalId
    })

    throw uploadError
  }
}
