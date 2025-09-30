# Document Preview Specification

## Overview
Provide consistent preview thumbnails or metadata summaries for every document stored in Pineapple Portal without altering existing data models. Previews enhance visibility in document lists and build cards while keeping upload/build workflows responsive.

## Goals
- Surface meaningful visual context (cover page or representative frame) for preview-capable formats.
- Maintain parity between uploaded and generated documents.
- Keep preview generation asynchronous so uploads/builds stay fast.
- Fail gracefully: fall back to icon- or metadata-only cards when preview generation is unsupported or fails.

## Scope
- Applies to all stored documents (uploaded and generated) that have file metadata.
- Leaves Document and DocumentBuild schemas unchanged.
- Adds background processing, storage conventions, and view logic for previews and placeholders.

## Tooling Decisions
- **Raster image thumbnails:** Use the `image_processing` gem with the `ruby-vips` backend. Docker already includes `libvips`; this keeps conversions fast, low-memory, and handles EXIF rotation out of the box.
- **PDF first-page covers:** Install `poppler-utils` and shell out to `pdftoppm` for page-one rasterization, then resize/encode the output to WebP with the same Vips pipeline. No ImageMagick/Ghostscript dependency.
- **Background jobs:** Stick with Active Job on `:solid_queue`. Add a low-concurrency `document_previews` queue so PDF/image work cannot starve other jobs.
- **Caching preview state:** Use Redis (already required for Action Cable) to record thumbnail status and suppress duplicate jobs.
- **Thumbnail storage:** Persist WebP results to S3 using keys like `previews/<logical_id>/v<version>.webp`, piggybacking on existing `aws-sdk-s3` wiring and CDN configuration.

## Document Type Handling
- Raster images (jpg, jpeg, png, webp, heic/heif, tiff, bmp): reuse original asset; produce max-600×600 WebP thumbnail via `image_processing` + Vips.
- PDFs: render page 1 at 2× density using Poppler (`pdftoppm`), then downscale/encode to WebP via Vips.
- All other file types (video, office docs, spreadsheets, audio, archives, plain text, etc.): no file processing. Cards render a metadata cover that shows the document title, file extension, and size using data already stored on the record.

## Generation Pipeline
- Background job (`DocumentPreviewJob`) enqueued when a document upload or build completes and the file is a PDF or raster image.
- Job resolves file via existing `storage_uri`, streams to tempfiles to respect memory limits.
- Delegates to `Previewers::Pdf` (Poppler + Vips) or `Previewers::RasterImage` (Vips), each returning processed IO + metadata or a `PreviewUnsupported` result.
- Enforce timeouts and size limits to guard CPU usage (e.g., skip previews above 200 MB, cap render time at 60s).
- Record last-attempt status in Redis (logical_id+version key) to prevent rapid retries; exponential backoff on transient failures.
- Provide instrumentation (ActiveSupport notifications) logging duration, content type, and error summaries.

## Storage & Caching
- Persist generated thumbnails to existing object storage using deterministic keys: `previews/<logical_id>/v<version>/<style>.webp`.
- Store preview key in Redis cache or memo column; no schema change required initially.
- Use versioned paths for cache busting and set long-lived CDN headers.
- Expose helper `DocumentPreviewFetcher` that:
  1. Checks cached preview key.
  2. Issues storage HEAD to confirm asset.
  3. If missing, re-enqueues job (with backoff) and signals placeholder UI state.

## Display Behavior
- Document/build cards request preview via helper and render three states:
  - Thumbnail image when available (lazy-loaded `<img>` with aspect-ratio box).
  - "Preview processing…" message plus icon while a PDF/image job is pending.
  - Metadata cover (title, extension badge, size) for unsupported types or when thumbnail generation fails.
- Maintain accessible text alternatives (alt/ARIA) using document title and status.
- Reuse existing action buttons; previews must not change card dimensions.

## Operational Considerations
- Ensure runtime image stack includes required tools: Poppler (`poppler-utils`), Vips (`libvips`), and `pdfinfo`.
- Validate availability locally and in production containers; document install steps.
- Monitor job queue impact; previews may require separate worker queue with CPU-bound limits.
- Consider feature flag (`:document_previews`) for gradual rollout.

## Open Questions
- Should preview storage keys be persisted on Document rows for faster lookup instead of Redis cache?
- What SLA should we set before flipping from "Preview processing…" to the metadata cover (e.g., after 3 failed attempts)?
- Are there document size thresholds beyond which we skip thumbnail generation entirely?
- Do we ever want to expand thumbnail support beyond PDFs/images, or is the metadata cover sufficient long term?
- Can we accept Poppler/Vips dependencies in all hosting environments, or do we need container updates first?

## Implementation Phases
1. **Foundation**: introduce preview service interface, storage key convention, background job, helpers, and feature flag.
2. **PDF & Raster Images**: implement previewers, connect to document cards, ensure fallbacks to metadata covers.
3. **Monitoring & Hardening**: add metrics, alerting, admin visibility, and refine retry/backoff thresholds.
