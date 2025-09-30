What you are building
Build a Generated Document feature that lets users assemble a single PDF from ordered segments. Segments can be uploaded PDFs or branded pages rendered by our app. Every export creates a new version in the existing documents table. Only changed segments are re rendered. Unchanged segments are reused from storage and re stitched.
Scope at a glance
Configure a generated doc using ordered segments.
Export builds a new document version using cached segment PDFs plus any changed ones.
View and Download always serve the latest document version.
Publish worthy edits trigger targeted rebuilds of only affected docs.
Support Templates and Duplicate from Template. Duplicating copies segment definitions but clears asset bindings so editors attach event specific files.
Data model additions (fit into current schema)
documents (already in schema)
Keep as single source of truth for all versions.
Add:
doc_kind string. Values: uploaded, generated. Default uploaded.
is_template boolean. Default false.
template_source_logical_id uuid. Nullable. Logical_id of the template or source definition this doc was created from.
Notes
Versions already handled by logical_id, version, is_latest.
Each export inserts a new row with the same logical_id, bumps version, flips is_latest.
document_segments (new)
Defines the ordered pieces for a logical generated document.
Columns
id bigint pk
document_logical_id uuid. FK to documents.logical_id
position integer
kind string. pdf_asset or html_brand
title string
source_ref jsonb
If pdf_asset: {document_logical_id, version?} or another stable reference
If html_brand: {template_key, params, as_of?}
spec jsonb. Human readable SegmentSpec snapshot (label, description, layout, params schema, data source summary, version)
created_at, updated_at
Indexes (in words)
Unique index on (document_logical_id, position)
Index on document_logical_id
document_dependencies (new)
Reverse index to rebuild only affected docs.
Columns
id bigint pk
document_logical_id uuid
segment_id bigint fk to document_segments
entity_type string. Example Guest, Contact
entity_id bigint
created_at timestamp
Indexes (in words)
Index on (entity_type, entity_id)
Index on document_logical_id
Storage layout (R2)
Segment PDF cache. segments/<segment_hash>.pdf
Final versions. documents/<logical_id>/v<version>.pdf
segment_hash is a content hash of kind, source_ref, template version, params, as_of, and any render opts.
Lifecycle
Export flow
Load segment rows for the doc logical_id, ordered by position.
For each segment compute segment_hash.
If segments/<segment_hash>.pdf exists reuse it.
Else render to a standalone PDF and upload to that key.
Stitch segment PDFs in order to one PDF.
Upload to documents/<logical_id>/v<version>.pdf.
Insert a new row in documents with same logical_id, incremented version, is_latest = true, and file fields set. Set previous latest to false.
During the build write document_dependencies rows for data backed segments. One per referenced entity.
View and Download
Resolve to the latest documents row for the logical document, or a selected historical version.
Serve inline for View or with attachment disposition for Download.
No mixed live HTML in the viewer. What you view is what you download.
Publish worthy data change
Editor marks a change as publish.
Emit an app event with entity_type and entity_id.
Lookup affected logical docs via document_dependencies.
Enqueue rebuild jobs for those docs.
Each job runs the Export flow. Only segments with changed hash are re rendered. All others are reused. Always produces a new documents version.
Templates and duplication
Mark as Template
On a generated doc definition set is_template = true on its logical doc.
Templates are definitions. They typically do not have exported versions.
Create from Template
User picks a template. System creates a new logical doc:
doc_kind = generated
is_template = false
template_source_logical_id = template.logical_id
Copy document_segments rows with same position, kind, title, spec, template_key and safe params.
Scrub bindings:
For pdf_asset set source_ref to empty so the editor must attach an event specific file.
For html_brand keep layout and safe params. Strip IDs and event specific filters unless intentional.
Do not copy dependencies. They are recomputed on next export.
Duplicate existing generated doc
Same as Create from Template but template_source_logical_id points to the source doc.
Option: Keep bindings on duplicate. Default off.
SegmentSpec to explain segments
Store a human readable spec snapshot in document_segments.spec and show it in the UI.
Suggested fields
key, label, description
kind
layout template_key
params_schema
data_source summary and as_of behavior
outputs. Page size, margins, expected page range
version of the template
owner and notes
Editor UX
Document composition view
List segments in order with title, kind, layout key, last segment_hash tail, last built page count.
Actions per segment: Preview, Rebuild segment cache, Edit params or Attach file (for pdf_asset).
Global actions: View latest, Download latest, Refresh if inputs changed, Save as Template, Duplicate.
Segment inspector drawer
Overview. Label, description, kind, layout, version, owner.
Data. Data source, params, dependencies count. Link to view dependency list.
Output. Page size, margins, expected vs last built pages.
Technical. Last segment_hash, cache hit or miss at last build.
Blocking rules
Export blocks if any required pdf_asset has no file attached. Show which segments block with a clear message.
Operational rules and guardrails
Uploaded PDFs referenced by pdf_asset are passed through unchanged. Validate only.
Branded segments are fully styled in their own render. Avoid stamping uploaded pages.
Normalize page size and orientation consistently on merge. Define once and reuse.
Determinism. Segment hash must include all inputs that affect bytes, including template version and any data cutoff.
Logging. Record per segment render time, cache hit or miss, pages, and any failures. Record manifest level totals.
Acceptance checklist
Data
Add doc_kind, is_template, template_source_logical_id to documents.
Create document_segments with fields listed above and indexes.
Create document_dependencies with fields and indexes.
Build
Compute segment_hash.
Cache segment PDFs in R2 by hash.
Stitch to a single PDF.
Insert a new documents version per export and flip is_latest.
Rebuilds
On publish worthy change, reverse lookup via document_dependencies.
Enqueue and run Export flow for affected logical docs only.
Templates and duplicate
Mark definition as Template.
Create from Template copies segments and scrubs bindings.
Duplicate has Keep bindings option.
UX
Composition panel with segment list.
Segment inspector drawer.
Clear errors when attachments are missing.
View and Download latest. Refresh when inputs change.
Audit
Each documents version shows checksum, size, content type, storage_uri, created time, built by.
Optional small diff summary at export. Count of segments changed since prior version.
