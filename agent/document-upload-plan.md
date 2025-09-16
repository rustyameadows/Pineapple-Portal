# Document Features Implementation Plan

## 1. Direct-to-R2 Upload Flow
- Add a signed-upload endpoint (`DocumentUploadsController#create`) that returns a presigned URL, object key, content type, and expected checksum fields.
- Define a service helper that builds R2 object keys (`documents/<logical_id>/v<version>/<original_filename>`).
- Secure the endpoint (require login) and log upload attempts for troubleshooting.

## 2. Client-Side Upload Workflow
- Enhance the new document form to accept a file input and optional metadata (title, logical ID for new version).
- Add JavaScript that requests a presigned URL, uploads the file via `fetch`/XHR, computes file size + checksum (SHA256), and populates hidden fields (`storage_uri`, `size_bytes`, `checksum`, `content_type`).
- Handle progress/error feedback in the form; block “Save” until the upload succeeds.

## 3. Document Creation & Versioning
- Update `DocumentsController#create` to trust the hidden fields from the upload step and validate presence.
- Auto-generate `logical_id` and version (existing logic) when not provided.
- For new versions, reuse the logical ID passed from the form and ensure prior versions get `is_latest = false` (already covered).

## 4. Download & Management UX
- In `documents#show`, add “Download latest” and “Download this version” links using presigned GET URLs.
- Add an event-scoped download route (`/events/:event_id/documents/:id/download`) that generates a presigned URL server-side and redirects the browser, keeping user-facing URLs tidy.
- Display upload timestamp, file size, checksum, and a button to copy the object key for manual inspection.
- Provide a table listing all versions (title, version, uploaded at, download link) to make history clear.

## 5. Attachments Enhancements
- For questionnaire/question answers, support direct uploads that create one-off documents (no version selection needed). Treat each answer attachment as its own document record with logical_id set automatically.
- Show download links in the attachments list so users can open linked files quickly.

## 6. Render & Credentials
- Confirm Render service env vars (`R2_*`) are set; document required setup in README (already noted, but verify instructions cover presigned flow).
- Optionally add a health check rake task (`rake r2:sign_test`) for operators to verify credentials post-deploy.

## 7. Testing Strategy
- Controller tests for the upload signing endpoint (ensuring presigned data returned, authentication enforced).
- System tests simulating the document upload flow via JS (can stub fetch or use Rails’ `ActionDispatch::IntegrationTest` with direct POST to verify metadata handling).
- Unit tests for any new services/helpers (key builder, checksum validator).

## 8. Follow-Up / Future Enhancements
- Optional background job to purge orphaned objects in R2 if a document record gets deleted.
- UI for bulk attachment management or linking multiple documents at once.
