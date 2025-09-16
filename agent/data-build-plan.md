# Data & Feature Build Plan

## Models & Database Schema

### Event (new)
- **Purpose**: Owns questionnaires and documents for a client engagement or production date.
- **Key fields**: `id`, `name`, `starts_on`, `ends_on`, `location`, timestamps.
- **Associations**: `has_many :questionnaires`, `has_many :documents`, `has_many :attachments, as: :entity` (for event-level files).

### Questionnaire (new table)
- **Columns**:
  - `id`, timestamps.
  - `event_id` (FK → events, required; templates remain tied to the originating event for now).
  - `title`, `description`.
  - `is_template` boolean default `false` for flagging reusable checklists.
  - `template_source_id` UUID FK → questionnaires (nullable, reserved for future template tracking).
- **Indexes/Constraints**: unique `[:event_id, :template_source_id]` when `template_source_id` present; simple index on `is_template` for listing.
- **Associations**: `belongs_to :event`; `belongs_to :template_source, class_name: "Questionnaire", optional`; `has_many :questions`; `has_many :attachments, as: :entity`.

### Question (new table)
- **Columns**:
  - `id`, timestamps.
  - `questionnaire_id` (FK → questionnaires, required).
  - `event_id` (FK → events, redundant but denormalised for quick lookup, always matches parent questionnaire’s event).
  - Content and answer fields: `prompt`, `help_text`, `response_type`, `answer_value`, `answer_raw`, `answered_at`.
- **Rules**: when `is_template` on parent, `event_id` populated same as parent and answer fields left NULL; validation ensures non-templates require event-specific answers.
- **Associations**: `belongs_to :questionnaire`; `belongs_to :event`; `has_many :attachments, as: :entity` (for prompt/help assets) and `has_many :answer_attachments` (scoped context `answer`).

### Document (new table)
- **Columns**:
  - `id`, timestamps.
  - `event_id` FK → events.
  - `title`, `storage_uri`, `checksum`, `size_bytes`.
  - Versioning: `logical_id` UUID (required), `version` integer (starting at 1), `is_latest` boolean default true.
- **Indexes/Constraints**: unique `[:logical_id, :version]`; partial unique index on `logical_id` where `is_latest` true; before-update safeguard preventing file metadata changes.
- **Associations**: `belongs_to :event`; `has_many :attachments`.
- **Storage**: files stored in Cloudflare R2. A service object will generate presigned upload/download URLs, and `storage_uri` will hold the R2 object key (e.g., `documents/<logical_id>/v<version>`).

### Attachment (new table)
- **Columns**:
  - `id`, timestamps.
  - Polymorphic `entity_type` / `entity_id` (can point to Event, Questionnaire, Question, or Question answer entity).
  - Document references: `document_id` (FK → documents) nullable; `document_logical_id` UUID nullable.
  - Metadata: `context` enum (`prompt`, `help_text`, `answer`, `other`, default `other`), `position` integer default 1, `notes`.
- **Constraints**: exactly one of `document_id` or `document_logical_id` is present; unique composite `[entity_type, entity_id, context, position]`.
- **Associations**: `belongs_to :document, optional`; helper to resolve latest document via `document_logical_id`.

## Controllers & Services

### EventsController
- CRUD for events plus dashboard linking to questionnaires/documents.
- "Import templates" action can be added later (out of scope now but kept in mind).

### QuestionnairesController
- Standard CRUD with additional list filtering: `/questionnaires/templates` to view template catalog.
- Form field to mark `is_template` (available only to admins).
- Show page displays associated questions and attachments.

### QuestionsController
- Nested under questionnaires for create/update/destroy.
- Handles prompt/help text, answer fields, and inline attachment uploads (future friendly).

### DocumentsController
- CRUD with ability to upload a new version: create action either starts a new logical document or appends a version (by passing `logical_id`).
- Flip previous version’s `is_latest` when new version created.

### AttachmentsController
- Manages attachments across host entities (create/update/destroy).
- Accepts either `document_id` or `document_logical_id` and enforces context/position uniqueness.

### Sessions/Auth
- Reuse existing flow; controllers will use `before_action :require_login` already in place.

## Views & UI

### Styling Guideline
- Keep presentation close to Rails defaults—semantic HTML, minimal CSS. Remove previously added heavy styling so future design work starts from a clean slate.

### Events
- Index/listing with links to each event’s questionnaires and documents.
- Event show page summarises documents, questionnaires, and attachments.

### Questionnaires & Questions
- Index filtered by event; separate template list view.
- Form partial for create/edit with `is_template` checkbox.
- Question nested forms using Turbo frames for quick add/edit.

### Documents
- Event-level index page showing latest version and link to history.
- Document show view listing versions, with call-to-action to upload new version.

### Attachments
- Form partial reused across host pages to add documents with context/position selectors.
- Display helpers showing attachment context badges and resolving latest document when using `document_logical_id`.

## Testing Approach
- Model specs for versioning logic, template validation, attachment constraints.
- Controller tests for CRUD flows and template filtering.
- System tests covering creating a questionnaire, marking as template, and listing templates; uploading document versions and verifying latest resolution.
- Service tests for R2 storage helper (upload/download URL generation).

## Open Questions
- Confirm whether template questionnaires should copy across events later (fields allow it); out of scope now but schema supports it.
- Cloudflare R2 integration will handle file storage via presigned URLs; plan to add credentials/config and simple service wrapper in this phase.
