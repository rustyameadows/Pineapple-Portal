

Product Brief: Generated Documents
Overview
The Generated Documents feature lets users assemble and export composite PDFs made up of segments. Segments may be uploaded PDFs (unaltered) or branded pages rendered by our app. Every export is a new version in the documentstable, consistent with how uploaded files already version.
This feature adds support for:
* Configuring documents from segments
* Exporting stitched PDFs with caching and reuse
* Versioning and history management via documents
* Dependency-based rebuilds when data changes
* Templates and duplication flows to speed setup

Goals
1. Users can create professional, branded packets by combining multiple sources.
2. Every export is a first-class document version, with the same UX as uploaded docs.
3. Avoid wasteful rebuilds by caching and reusing segment renders.
4. Rebuild only affected documents when critical data changes.
5. Provide templates and duplication to streamline repeat workflows.

Non-Goals
* We do not stamp or re-brand uploaded PDFs. They are passed through unchanged.
* We do not mix live HTML with PDFs in the viewer; users always see the same compiled artifact.

Data Model
documents (existing)
Already versioned by logical_id, version, is_latest. New columns
* doc_kind (string): "uploaded" or "generated".
* is_template (boolean, default false). Marks a logical document as a reusable template.
* template_source_logical_id (uuid, nullable). Source template or document this was duplicated from.
document_segments (new)
Defines ordered building blocks for a logical generated document.
Column	Type	Description
id	bigint	Primary key
document_logical_id	uuid	References documents.logical_id
position	integer	Order in document
kind	string	pdf_asset or html_brand
title	string	Segment title for display/bookmarks
source_ref	jsonb	Reference details: document/version or template/params
spec	jsonb	Human-readable spec snapshot (label, description, layout, params schema, etc.)
created_at	timestamp
updated_at	timestamp
Indexes:
* (document_logical_id, position) for ordered fetch
* document_logical_id for grouping
document_dependencies (new)
Reverse index to determine which docs depend on which records.
Column	Type	Description
id	bigint	Primary key
document_logical_id	uuid	Which logical doc depends on the entity
segment_id	bigint	Which segment
entity_type	string	e.g., Guest, Contact
entity_id	bigint	PK of the entity
created_at	timestamp
Indexes:
* (entity_type, entity_id) for fast reverse lookup
* document_logical_id for grouping

Storage Layout
* Segment cache PDFs: stored in R2 at segments/<segment_hash>.pdf.
* Final versions: stored in R2 at documents/<logical_id>/v<version>.pdf.
segment_hash includes all inputs that affect bytes: kind, source_ref, template version, params, and as_of timestamp.

Lifecycle
Export flow
1. Load segments by document_logical_id.
2. Compute segment_hash for each.
3. Reuse cached PDF if it exists; else render and upload.
4. Stitch all PDFs together into one file.
5. Upload stitched file to R2 at versioned path.
6. Insert a new row in documents (same logical_id, increment version, set is_latest=true, flip old).
7. Record document_dependencies for any data-backed segments.
View & Download
* Always resolve to latest documents row unless user chooses a historical version.
* Serve inline for viewing or as attachment for download.
* No live HTML mixed in.
Publish-worthy data changes
1. Editor marks a change as “publish.”
2. Emit event with entity_type, entity_id.
3. Lookup dependencies to find affected logical docs.
4. Enqueue rebuild jobs for each.
5. Jobs run Export flow, only re-rendering changed segments.

Templates & Duplication
Mark as Template
* Action: “Save as Template.”
* Sets is_template=true for the logical document.
* Typically no exports exist for templates.
Create from Template
* User selects a template.
* System creates a new logical doc:
    * doc_kind=generated
    * is_template=false
    * template_source_logical_id set
* Copies segments but scrubs asset bindings:
    * pdf_asset → clears source_ref so editor must attach
    * html_brand → keeps layout + safe params, strips IDs/event-specific refs
* Dependencies will repopulate at first export.
Duplicate
* Same as Create from Template but source is another doc.
* Option: “Keep bindings” (default off).

SegmentSpec (explaining segments)
Each segment row includes a spec field to explain:
* Label, description, layout, version, params schema, data source, expected output, owner.
This powers the Segment Inspector UI, showing what the segment does and where data comes from.

User Experience
Composition View
* Ordered list of segments with titles, kind, template, last hash, page count.
* Actions per segment: Preview, Rebuild cache, Edit params/Attach file.
* Global actions: View latest, Download latest, Refresh if manifest changed, Save as Template, Duplicate.
Segment Inspector
* Overview: label, description, kind, layout, version, owner.
* Data: data source, params, dependencies.
* Output: page size, margins, page counts.
* Technical: last hash, cache status.
Blocking Rules
* Export is blocked if required pdf_asset segments lack attachments.
* UI clearly indicates missing pieces.

Operational Guardrails
* Uploaded PDFs are passed through unaltered.
* Branded pages include styling and branding.
* Page size/orientation normalized at stitch.
* Segment hash must deterministically cover all inputs.
* Logs record segment render times, cache hits/misses, and failures.

Acceptance Checklist
Data
* Extend documents with doc_kind, is_template, template_source_logical_id.
* Create document_segments table.
* Create document_dependencies table.
Build
* Segment hash computation.
* Segment PDF caching in R2.
* Stitch PDFs.
* Insert new documents row per export.
Rebuilds
* Reverse lookup via dependencies.
* Rebuild only affected docs.
Templates & Duplication
* Save as Template flow.
* Create from Template with scrubbed bindings.
* Duplicate with optional bindings.
UX
* Composition panel.
* Segment inspector.
* Error handling for missing attachments.
* View/Download latest, Refresh if stale.
Audit
* Each document version shows checksum, size, content_type, storage_uri, created_at, built_by.
* Optional diff summary: count of segments changed.



📄 Generated Documents: How to Use Them
Generated Documents let you create professional packets by combining multiple pieces — uploaded PDFs, branded covers, guest lists, contact sheets, and more — into a single document you can view, download, and version just like any other file in the system.

What You Can Do
* Assemble packets: Choose the segments you want (cover, agreements, floor plans, etc.) and order them however you like.
* Mix sources: Segments can be uploaded PDFs or branded layouts that pull directly from your event data (like a guest list).
* Keep history: Every time you export a generated document, it’s saved as a new version. You can always go back.
* Refresh when data changes: Update just the parts of the document that matter and generate a new version without re-doing everything.
* Use templates: Save a generated document as a template, or create new ones by duplicating a template. This saves time by giving you a predefined structure (like “Vendor Packet”) where you just attach the event-specific files.

Creating a Generated Document
1. Go to your event’s Documents section.
2. Click New Document → Generated.
3. Add segments in the order you want them to appear:
    * Uploaded PDF segments: choose from files you’ve already uploaded.
    * Branded Page segments: select from layouts like “Cover” or “Guest List.” These automatically style and pull in your event’s data.
4. Give your document a title (e.g., “Vendor Packet”).
5. Save.

Exporting and Viewing
* When you’re ready, click Export.
* The system will build your document by combining all the segments into one PDF.
* You’ll see the compiled file in the Documents list.
* Click to View in your browser, or Download to save locally.
* Each export automatically becomes a new version of your document, so you can always check back to older ones.

Refreshing When Data Changes
* Some edits (like updating a phone number) are marked publish-worthy. When you save these, the system will rebuild any generated documents that depend on that data.
* For less critical edits (like adding one more RSVP), you can just save. The generated document won’t change until you manually refresh.
* In the document view, you may see a Refresh option if the content has changed since the last export.

Using Templates
* Save as Template: If you’ve built a useful structure (like a standard vendor packet), mark it as a template. This saves the definition but clears any event-specific attachments.
* Create from Template: When starting a new document, pick a template. You’ll get all the segments pre-configured — e.g., “Cover Page,” “Vendor Agreement,” “Floor Plan” — but you’ll need to attach your own PDFs where required.
* Duplicate an Existing Document: Copy a document you already have. By default, sources are cleared so you can re-use the structure. You can also choose to keep the existing file attachments.

Managing Versions
* Every time you export, you create a new version.
* The latest version is always the one shown by default.
* You can view and download older versions from the document history.

Key Things to Know
* Uploaded PDFs are never changed. They appear exactly as you uploaded them.
* Branded pages are styled by us, so covers and lists look consistent and professional.
* You can’t mix “live views” with PDFs — everything is compiled into one PDF for viewing and downloading.
* If a required segment is missing a file, the system won’t let you export. It will tell you which pieces need attention.
