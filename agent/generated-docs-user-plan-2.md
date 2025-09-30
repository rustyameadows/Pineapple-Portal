# Generated Documents - Functional Spec v1

## Purpose
Allow users to assemble professional packets by combining uploaded PDFs and branded pages into a single compiled PDF. Each export is a new first-class version in `documents`.

## Scope
In scope
- Configure documents from ordered segments
- Export and cache segment PDFs, stitch to one PDF
- Versioning and history in `documents`
- Dependency tracking and targeted rebuilds
- Templates and duplication flows

Out of scope
- Alteration of uploaded PDFs beyond normalization
- Mixing live HTML with the viewer. Users always view a compiled PDF

## Definitions
- Logical Document: a stable `logical_id` with many versions in `documents`
- Segment: an ordered unit inside a logical document. Types: `pdf_asset`, `html_brand`
- Segment Cache: a rendered PDF for a single segment keyed by `segment_hash`
- Manifest: the ordered list of segments plus their effective inputs
- As Of: timestamp used to bound data reads for deterministic bytes

## Data Model

### `documents` (existing)
New columns
- `doc_kind` string. Values: `uploaded`, `generated`
- `is_template` boolean default false
- `template_source_logical_id` uuid nullable

Constraints and indexes
- Unique `(logical_id, version)`
- Partial index on `is_latest = true` for fast latest lookup
- Default `doc_kind = 'uploaded'` for backfill

### `document_segments` (new)
Defines ordered segments for a generated logical document.

Columns
- `id` bigint PK
- `document_logical_id` uuid FK to `documents.logical_id`
- `position` int, 1-based
- `kind` string. `pdf_asset` or `html_brand`
- `title` string for display and bookmarks
- `source_ref` jsonb. For `pdf_asset`: { logical_id, version? }. For `html_brand`: { template_key, template_version, params, as_of }
- `spec` jsonb. Snapshot for inspector: { label, description, layout, version, params_schema, data_source, expected_output, owner }
- `created_at`, `updated_at` timestamps

Indexes
- Unique `(document_logical_id, position)`
- `document_logical_id` for grouping

### `document_dependencies` (new)
Reverse index to rebuild on data changes.

Columns
- `id` bigint PK
- `document_logical_id` uuid
- `segment_id` bigint
- `entity_type` string. Example: Guest, Contact
- `entity_id` bigint
- `created_at` timestamp

Indexes
- `(entity_type, entity_id)`
- `document_logical_id`

Write rule
- On successful export, clear existing rows for the logical document, then insert the new dependency set discovered during rendering

## Storage
- Segment caches: `r2://segments/<segment_hash>.pdf`
- Final versions: `r2://documents/<logical_id>/v<version>.pdf`
- Record on each document version: `checksum_sha256`, `size_bytes`, `content_type`, `storage_uri`, `created_at`, `built_by`, `build_id`, `manifest_hash`

## Hashing

### `segment_hash`
Inputs must deterministically cover all bytes:
- `kind`
- `source_ref` after canonicalization
- template version and layout
- params after canonicalization
- `as_of` ISO 8601 to bound data
- renderer version
- normalization options used at stitch time that affect the segment

Canonicalization rules
- JSON stable ordering by key
- Trim whitespace, drop nulls where semantically empty
- Numbers serialized as strings with fixed precision when needed
- Hash algorithm: SHA-256 to hex

### `manifest_hash`
- Concatenate `segment_hash` values in order with a separator and hash again with SHA-256

## Export Pipeline

Steps
1. Load segments for `document_logical_id` ordered by `position`
2. Compute `segment_hash` for each segment
3. For each segment, try cache by `segment_hash`. If miss, render, upload to R2, record bytes and checksum
4. Stitch segment PDFs into one output using a streaming pipeline
5. Normalize page size and orientation as configured. Flatten forms. Preserve embedded fonts if present
6. Add PDF bookmarks using segment `title` and starting page indexes
7. Compute `manifest_hash` and `checksum_sha256` for the stitched PDF
8. Insert a new row in `documents` with incremented `version`, set `is_latest = true`, flip old versions to false
9. Upsert `document_dependencies` discovered during render
10. Emit `document.exported` event with `logical_id`, `version`, `build_id`, `manifest_hash`, timings, cache metrics

Idempotency and concurrency
- Define `build_id` uuid per export attempt
- Guard latest write with a transactional check that re-reads `is_latest`
- Optional no-op optimization: if an export request provides an expected `manifest_hash` equal to the latest, skip creating a new version and return the latest

Permissions
- Validate read permission for every referenced asset and data source at render time
- If any check fails, the export fails with a clear error and no version is created

Preflight and limits
- Reject password-protected or corrupt PDFs
- Enforce max pages and max output size
- Timeouts per segment render and overall build
- Clear errors per segment and a roll-up message

## Rebuilds on Publish-worthy Changes

Flow
1. Editor marks a change as publish
2. Emit `data.change` event with `entity_type`, `entity_id`, `as_of`
3. Lookup `document_dependencies` by `(entity_type, entity_id)` to find logical documents
4. Enqueue one rebuild job per logical document with dedupe key `(logical_id)`
5. Job runs the Export Pipeline. Only segments whose `segment_hash` changed will re-render. Others hit cache

## Templates and Duplication

Mark as template
- Action sets `is_template = true` on the logical document
- Templates usually have no exports

Create from template
- Create a new logical document with `doc_kind = generated`, `is_template = false`, `template_source_logical_id` set
- Copy segments, scrub bindings
  - `pdf_asset` clears `source_ref`
  - `html_brand` keeps layout and safe params, strips IDs and event-specific refs
- Dependencies populate on first export

Duplicate
- Same as create from template, source is a non-template document
- Option `keep_bindings` default false

## User Experience

Composition view
- Ordered list of segments with title, kind, last known hash, last known page count
- Per-segment actions: Preview cached PDF, Rebuild cache, Edit params or Attach file
- Global actions: View latest, Download latest, Export, Save as Template, Duplicate, Refresh if manifest changed

Segment inspector
- Overview: label, description, kind, layout, version, owner
- Data: data source, params, dependencies
- Output: page size, margins, page counts
- Technical: last hash, cache status, renderer version

Blocking rules
- Export blocked if required `pdf_asset` segments do not have attachments
- UI highlights missing pieces with exact segment positions

Staleness
- If current manifest differs from the latest version `manifest_hash`, show Refresh banner and CTA

## Operational Guardrails
- Uploaded PDFs are passed through unaltered except normalization
- Branded pages include styling and brand
- Stitching is streaming to bound memory
- Logs capture render times, cache hits and misses, dependency count, and failures
- GC policy for segment caches: LRU with size cap and last_used_at tracked in object metadata

## Observability
Metrics
- Segment cache hit rate
- P50, P95, P99 for segment render and stitch times
- Export failure rate and top error reasons
- Average pages per export and output size

Logging
- Correlate by `build_id` and `logical_id`
- Include `manifest_hash` and per-segment `segment_hash` list

## Migrations
- Add new columns to `documents` with defaults
- Backfill `doc_kind = uploaded` for existing rows
- Create `document_segments` and `document_dependencies`
- Add indexes and unique constraints as listed
- Feature flag to gate export endpoints until backfill completes

## Acceptance Criteria

Data
- `documents` has `doc_kind`, `is_template`, `template_source_logical_id`
- `document_segments` and `document_dependencies` exist with indexes

Build
- Deterministic `segment_hash` and `manifest_hash`
- Segment cache read and write in R2
- Streaming stitch with bookmarks
- New `documents` row per export with audit fields set

Rebuilds
- Reverse lookup via dependencies works
- Rebuild only re-renders changed segments

Templates and duplication
- Save as Template
- Create from Template with scrubbed bindings
- Duplicate with optional keep bindings

UX
- Composition panel and Segment inspector
- Clear errors for missing attachments
- View and Download latest
- Refresh banner when stale

Audit
- Each version records checksum, size, content_type, storage_uri, created_at, built_by, build_id, manifest_hash
- Optional diff summary: count of segments changed and which positions changed
