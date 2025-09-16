# Database Additions: Templates & Versioned Docs

This document describes **additions** to an existing database, focused on templates and versioned documents.

---

## New / Modified Tables

### questionnaires (modified)

* Add `is_template boolean default false`
* Add `template_source_id UUID nullable FK → questionnaires.id` (set when generated from a template)
* Add `auto_generate boolean default false` (for templates that should auto-generate for new events)
* Modify `event_id` → nullable when `is_template = true`

**Constraints**:

* If is\_template = true → event\_id IS NULL.
* If is\_template = false → event\_id IS NOT NULL.
* unique (event\_id, template\_source\_id) prevents generating same template twice per event.

---

### questions (modified)

* event\_id may be NULL when parent questionnaire is a template.
* Answer fields (answer\_value, answer\_raw, answered\_at, etc.) only populated when is\_template = false.

**Constraints**:

* If parent questionnaire is a template → event\_id IS NULL and no answers.
* If parent questionnaire is an instance → event\_id = questionnaires.event\_id.

---

### documents (modified for versioning)

* Add `logical_id UUID required` (shared across versions of the same doc)
* Add `version int required` (monotonic starting at 1)
* Add `is_latest boolean required default true`

**Constraints**:

* unique (logical\_id, version)
* partial unique index: (logical\_id) where is\_latest = true
* Immutability: storage\_uri/checksum/size\_bytes not updated after insert

---

### attachments (modified)

* Allow referencing either a fixed `doc_id` or a `logical_id` (for latest resolution).
* Add `context ENUM {prompt, help_text, answer, other} default other` to clarify usage.
* Add `position int default 1` for ordering.

**Constraints**:

* Exactly one of doc\_id or logical\_id must be set.
* unique (entity\_type, entity\_id, context, position).

---

## Workflows

### Template Creation

* Mark an existing questionnaire as template → set is\_template = true, event\_id = NULL.
* Clear all answers and any answer attachments.

### Template Instantiation for Event

1. Insert questionnaire with event\_id = event.id, is\_template = false, template\_source\_id = template.id.
2. Copy questions, clear answers, set event\_id = event.id.
3. Copy non-answer attachments (prompt/help).

### Document Versioning

* New version: insert new documents row with same logical\_id, version = prev+1, is\_latest = true.
* Flip previous is\_latest = false.
* Attachments can use either doc\_id (fixed version) or logical\_id (resolve latest).

### UI Flow for Template Generation

* User selects templates from list (checkboxes).
* Backend generates instances for selected templates for the new event.
* unique (event\_id, template\_source\_id) ensures no duplicates.

---

## Optional Audit Tables

* **template\_generation\_jobs**: (event\_id, status, created\_at)
* **template\_generation\_items**: (job\_id, template\_id, generated\_questionnaire\_id, status)

---

## Summary of Additions

* **Templates**: new flags and relationships on questionnaires and questions.
* **Versioned Documents**: logical\_id, version, is\_latest fields + constraints.
* **Flexible Attachments**: now support both fixed version (doc\_id) and rolling latest (logical\_id), plus contexts.

These additions extend your existing DB without requiring a full re-spec.
