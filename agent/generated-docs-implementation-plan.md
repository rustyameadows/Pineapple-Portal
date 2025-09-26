# Generated Documents – Implementation Plan

## 1. Goals & Constraints
- **Goal**: deliver the full generated-documents system described in user plan #3. Planners assemble a packet from ordered segments, exports create new versions in `documents`, segment caches avoid redundant renders, and publish-worthy data changes trigger targeted rebuilds.
- **Scope**: honor every functional requirement in plan #3 (segment caching, dependency tracking, templates/duplication, inspector tooling). Initial HTML views leverage data we already have (event overview, planning team, timeline) and more views can be added later without changing infrastructure.
- **Principles**: reuse existing models/controllers/helpers wherever possible, keep render pipeline deterministic, and store every compiled PDF as a versioned asset in R2.

## 2. High-Level Flow
1. Planner opens a new “Generated Packet” builder under Documents.
2. Builder lets planner order **Segments**:
   - **Branded HTML sections** with data pulled from the app (event overview, planning team, calendar summary, checklist).
   - **Existing uploaded PDFs** (select from the event’s `documents` list or upload inline).
3. Planner runs “Compile packet” → background job renders each segment to PDF (or reuses the raw PDF) → stitches into one compiled PDF saved as a new `Document` version.
4. Document list shows generated version alongside uploads; planner can download or regenerate.

## 3. Data Model Adjustments
- **documents table**
  - Add `doc_kind` (`uploaded`, `generated`). Default existing rows to `uploaded`.
  - Add `is_template` (default `false`) and `template_source_logical_id` (nullable UUID) for template & duplication flows.
  - Add `built_by_user_id`, `build_id`, `doc_kind`-specific metadata columns (`manifest_hash`, `checksum_sha256`).
- **document_segments table** (new)
  - Columns: `id`, `document_logical_id` (UUID FK to `documents.logical_id`), `position`, `kind` (`pdf_asset`, `html_view`), `title`, `source_ref` (JSON canonical payload), `spec` (SegmentSpec snapshot), timestamps.
  - Unique index on `(document_logical_id, position)` plus standard FK index.
- **document_dependencies table** (new)
  - Columns: `id`, `document_logical_id`, `segment_id`, `entity_type`, `entity_id`, timestamps.
  - Index on `(entity_type, entity_id)` for reverse lookups; secondary index on `document_logical_id`.
  - Populated after each export based on data sources touched while rendering HTML views.

## 4. Segment Types
1. **`pdf_asset`**
   - Planner picks an existing document version (`uploaded`).
   - `source_payload` stores `{ logical_id, version }`.
   - Rendering step simply normalizes the stored PDF (no transformation).
2. **`html_view`** (print view templates)
   - Predefined “print view” templates rendered server-side via ERB + WickedPDF/Grover.
   - Each view is treated like a printable layout (not the standard UI view). We maintain a library under `app/views/generated_documents/sections/<view_name>.html.erb` with matching CSS.
   - Initial views (pull from existing data sources):
     - `planning_team` – reuse `event.planner_team_members` helper to list names, titles, contact info.
     - `event_overview` – render hero block with event dates/location similar to portal header.
     - `timeline` – summarize decision calendar or run-of-show milestones (reuse `Calendars` helpers).
     - Future views can be added by designers without touching the builder logic.
   - `source_payload` stores `{ view_key, params }`; params allow toggling sections, custom notes, etc.
   - Rendering service loads the selected view, applies print stylesheet, converts to PDF.

## 5. Rendering Pipeline
- Implement service `Documents::Generated::Builder`:
  1. Load ordered `document_segments` for logical document (latest manifest).
  2. For each segment:
     - `pdf_asset`: fetch original from R2 (`storage_uri`) and stream to temp.
     - `html_view`: render print template with current data and params, convert to PDF. Track entities touched for dependency writes.
  3. For each segment compute `segment_hash`. Attempt download from `segments/<segment_hash>.pdf`. If cache miss, render and upload to that key.
  4. Concatenate PDFs using CombinePDF (or equivalent streaming merger).
  5. Normalize (page size, orientation), add bookmarks by segment title, compute `manifest_hash`.
  6. Upload final PDF to `documents/<logical_id>/v<version>.pdf`, insert new row in `documents` (`is_latest = true`, flip previous latest).
  7. Write `document_dependencies` (wipe old entries and bulk insert new ones).
  8. Emit `Documents::Exported` event with telemetry (segment cache hits/misses, timings, dependency count).

## 6. User Experience (Planner UI)
- **Entry point**
  - On `documents#index`, add “Create Generated Packet” CTA (feature gated by flag).
- **Composition View** (`Documents::GeneratedController#edit`)
  - Ordered segment list (Stimulus sortable) showing title, kind, view key, last hash tail, last build page count.
  - Per-segment actions: Preview cached PDF, Rebuild segment cache (force re-render), Edit params, Attach/replace asset for `pdf_asset`.
  - Global actions: View latest export, Download latest, Refresh (when manifest differs), Save as Template, Duplicate.
  - Highlight blocks when required assets are missing (blocking export).
- **Segment Inspector drawer**
  - Overview: label, description, kind, layout key, version, owner.
  - Data: data source summary, params, dependency count with link.
  - Output: page size, margins, expected vs. last built pages.
  - Technical: last `segment_hash`, cache hit/miss info, renderer version.
- **Compile Action**
  - POST `/events/:event_id/documents/:logical_id/compile` triggers job.
  - UI shows toast “Compilation started”; manifest banner updates (staleness vs. refreshed).
  - On success, show diff summary (count of segments changed vs. prior manifest).

## 7. Background Jobs
- Add `Documents::Generated::CompileJob` (ActiveJob).
- Accepts `document_logical_id`, `event_id`, `initiating_user_id`, optional target `manifest_hash`.
- Uses builder service, persists new version, logs metrics, writes dependencies, emits event.
- Use advisory lock keyed on `document_logical_id` to prevent overlapping builds.
- Provide retry/backoff strategy; flag doc as failed when retries exhausted so UI can display error state.

## 8. Permissions & Security
- Reuse existing planner authorization (only planners/admins can manage documents).
- Validate access to every referenced asset and data source during render; fail fast with clear errors.
- Record `built_by_user_id`, `build_id`, `manifest_hash`, `segment_hashes` for auditing.

## 9. Migrations
1. Add columns to `documents` (`doc_kind`, `is_template`, `template_source_logical_id`, `built_by_user_id`, `build_notes`?).
2. Backfill existing rows with `doc_kind: 'uploaded'`.
3. Create `document_segments` with fields above, FK to `documents` (on delete cascade).
4. Create `document_dependencies` with indexes listed and FK to segments.
5. Provide backfill script to set `doc_kind='uploaded'` and `is_template=false` for existing docs.

## 10. Reuse of Existing Data
- **Event Overview**: `events` table fields (name, dates, location) and hero styling borrowed from client portal header.
- **Planning Team**: use `event.planner_team_members` query (already implemented for portal) to populate branded page.
- **Decision Calendar summary**: reuse aggregator from `Client::CalendarsController#decision_calendar_segments` (or run-of-show helpers) to produce timeline view data.
- **Future data sources** (guest list, budgets) can hook in later without schema changes.
- **Uploaded PDFs**: rely on existing `documents` R2 storage + `download` endpoint.

## 11. Implementation Milestones
1. **Data Layer**
   - Migrations, models (`DocumentSegment`), associations (`Document has_many :segments`).
   - Seed minimal fixtures for tests.
2. **Builder UI**
   - `Documents::GeneratedController` (new), basic views to add/reorder segments.
   - Stimulus controller for sortable list (reuses existing patterns).
3. **Rendering Service & Job**
   - Implement `Documents::Generated::Builder` with segment hashing, cache lookup/render/upload, stitching, normalization.
   - Integrate CombinePDF (or alternative) and HTML-to-PDF engine (WickedPDF/Grover).
   - Persist dependencies and emit export events.
4. **HTML View Templates (Initial Set)**
   - Create ERB layouts for `event_overview`, `planning_team`, `timeline`, each with dedicated print styles.
   - Extract data helpers into `GeneratedDocumentsHelper` for reuse and dependency tracking (record entities touched).
5. **Testing**
   - Model specs for `DocumentSegment` ordering.
   - Service specs for builder (stub R2, assert caching behavior).
   - Request specs for builder CRUD, compile endpoint, template creation/duplication.
6. **Feature Flag & Admin Hooks**
   - Wrap new navigation/CTA behind flag (`Flipper[:generated_documents]`).
   - Audit log entry and telemetry for each successful/failed build.

## 12. Risks & Mitigations
- **HTML-to-PDF rendering reliability**: choose renderer already allowed by security (WickedPDF). Accept that pages must match A4/Letter sizes.
- **Large combined outputs**: enforce soft limit (e.g., 30 segments, 50MB output). Fail gracefully.
- **Upload reuse**: ensure original PDFs remain accessible even if they’re archived (use `Document` version lookup with `is_latest`).
- **Job failures**: mark compilation job status in UI (badge “Last compile failed”) with retry CTA.

## 13. Future Enhancements
- Client portal access to compiled packets.
- Additional HTML views (guest list, budgets, vendor profiles) once data exists.
- Bookmark generator, advanced diff summary, PDF signing workflow.

## 14. Open Questions
- Preferred HTML-to-PDF renderer (WickedPDF vs. Grover vs. Prince).
- Should compiled PDFs live under new logical IDs or reuse existing doc when re-running compile? (Plan: new version for same logical ID.)
- How to present compile status in UI (toast + inline status or job center?).
- Storage billing concerns (need R2 lifecycle policy?).

## 15. Immediate Next Steps
1. Review migrations + schema changes with team (ensure `doc_kind` / segments align with future spec).
2. Confirm renderer choice with maintainer.
3. Set up feature flag.
4. Start implementation following milestones above.
