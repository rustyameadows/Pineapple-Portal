# Documents Cleanup Plan

## 1. Shared Table Component
- Build an ERB partial (e.g. `app/views/documents/_table.html.erb`) that renders a flexible table layout with columns for title, version badge, updated timestamp, visibility, source, uploader, size, and action links.
- Accept locals to control which columns/actions appear (planner vs. client context) and to override the empty-state copy so the same markup supports admin lists, staff uploads, and client uploads.
- Expose helpers for formatting version info (`v{number}` plus "Latest" marker) and visibility hints so both planner and client views stay consistent.

## 2. Planner Document Views
- Update `DocumentsController#index` and `#render_grouped_documents` views (`index`, `group`) to use the shared table partial instead of the current grid/card layout.
- Ensure group pages highlight version, uploader/source, file size, and updated timestamps, and swap the CTA row to match the table design.
- Refresh the upload/new/edit views to surface version/context info (current version, logical ID) so planners understand the history when replacing a file.
- Refine `show.html.erb` with structured sections: file metadata summary, version history table (calling the same helpers), and action links aligned to the new table look.

## 3. Portal Design & Inspiration Page
- Extend `Client::DesignsController#index` to load two collections:
  - Planner-provided inspiration (client-visible staff uploads/packets tagged appropriately).
  - Client-provided uploads (`source: :client_upload`).
- Render both collections with the shared table partial (scoped for the client shell) to display title, version, uploaded date, and a download link.
- Add an inline upload form that posts to a new `Client::DesignsController#create` action, wiring through `Document` creation with `source: :client_upload`, client visibility enabled, and the current client as the uploader reference if available.
- Reuse existing file-presign flow if required; otherwise provide a simple direct upload UI consistent with admin forms.

## 4. Backend & Routing Updates
- Introduce a `Client::DocumentsController` or extend `Client::DesignsController` to handle `create` (and optionally `destroy`) for client uploads, ensuring authorization and event scoping match existing portal patterns.
- Adjust routes to accept POST for `portal/events/:event_id/designs` and reuse existing `DocumentsController` strong parameters for safe attribute handling.
- Make sure saving a new client upload triggers version handling (logical IDs) and default visibility, and that planner-facing lists automatically include client contributions.

## 5. Version & Metadata Surfacing
- Add presenter/helper methods to surface version badges, latest flags, and uploader info so the shared table and detail page remain in sync.
- Confirm the table component and detail view display logical ID, version chain, size, checksum, and visibility state.
- Where planners can upload new versions, surface the current version number and auto-increment behavior to reduce confusion.

## 6. Tests & Fixtures
- Update or add controller/view tests covering:
  - Planner document group pages rendering tables with version metadata.
  - Client Design page showing planner uploads, client uploads, and handling new upload submissions.
  - Version badges and visibility info appearing in the shared partial.
- Expand fixtures/factories for documents (including multiple versions and client uploads) to support the new test coverage.

Let me know if you want any adjustments before I start coding.
