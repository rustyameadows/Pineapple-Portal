# Project Notes

## 2025-09-16 – Data Model Expansion Brainstorm

- Purpose: extend the event-planning portal with reusable questionnaire templates, versioned documents, and richer attachments.
- **Questionnaire Templates**: questionnaires are owned by events but can be flagged as templates (`is_template`) so planners can list reusable checklists. Template records behave like any other questionnaire for now; `template_source_id` stays available if we later track which template spawned an event copy.
- **Questions table impact**: questions inherit template vs instance behavior from parent questionnaire. Template questions have no event ID or answers; instantiated ones match event ID and collect responses once the event is active.
- **Documents**: introduce logical document IDs for contracts, schedules, etc., allowing multiple versions per document with an `is_latest` flag to track the live version while retaining history.
- **Attachments**: support linking to either a particular document version or the latest version, with context metadata (prompt/help_text/answer/other) and ordering to better render questionnaire materials. Document files will live in Cloudflare R2; attachments will use helpers to resolve signed URLs when we hook in the storage service.
- Next steps: design migrations/models/controllers/views for template management, event-driven instantiation, document versioning UI, and attachment workflows that leverage these new fields.
