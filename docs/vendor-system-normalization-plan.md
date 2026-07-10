# Vendor System Normalization Plan

## Purpose

This document is the durable implementation and rollout plan for moving vendor data to one strict hierarchy:

1. The global vendor library owns vendor identity, shared profile data, and everyone known at each vendor.
2. An event vendor links an event to a global vendor and owns event-specific configuration.
3. A Run of Show item links to one or more vendors already associated with its event.

The work is divided into four phases so schema changes, production data migration, planner content reconciliation, and final cleanup remain independently verifiable.

## Current Status

| Work | Status | Completion evidence |
| --- | --- | --- |
| Prevent event vendors from overwriting global contacts/profile data | Complete | Commit `2300cd1` |
| Add a read-only production vendor audit | Complete | Commit `7cfb18d` |
| Phase 1 — Contacts | Implemented locally; production verification pending | Local migration succeeded; 734 tests and contact audit verification pass |
| Phase 2 — ROS Transition | Not started | Begins after Phase 1 is deployed and verified |
| Phase 3 — Planner Reconciliation | Not started | Begins after Phase 2 transition UI is deployed |
| Phase 4 — Polish & Complete | Not started | Begins when meaningful legacy ROS vendor values reach zero |

Update this table and the phase checklists as work is completed. Do not remove historical completion notes.

## Locked Product and Data Decisions

1. `GlobalVendor` is the canonical vendor company record.
2. Global vendor name and social handle are global-owned.
3. Vendor type remains an event-level value, seeded from the global default when appropriate.
4. `EventVendor` must reference a `GlobalVendor` and remains the owner of:
   - event-specific vendor type;
   - selected event contacts;
   - team meal notes;
   - client visibility;
   - display ordering.
5. A global vendor can have multiple contacts.
6. An event vendor can select multiple contacts from its global vendor.
7. A ROS item can have multiple event vendors.
8. ROS vendor selectors show only vendors already associated with that event.
9. Adding a missing vendor to an event is an explicit global-library/event-roster workflow. ROS does not implicitly create or link global vendors.
10. Legacy `calendar_items.vendor_name` values become read-only migration data. New vendor changes write associations only.
11. Automatic ROS migration uses exact event-scoped matches only. No fuzzy match can modify production data.
12. Bulk editing uses additive and subtractive association actions. It does not replace existing vendors by default.
13. Existing migration files are never modified. Every schema or cleanup change uses a new migration.
14. The maintainer runs migrations and production backfill commands at explicit handoff points.

## Production Audit Baseline

Audit captured after the overwrite-prevention release:

### Global and event vendor structure

- Global vendors: 53
- Unused global vendors: 5
- Event vendors: 67
- Linked event vendors: 67
- Unlinked event vendors: 0
- Duplicate event/global groups: 0
- Linked event/global name mismatches: 1
- Event/global vendor type differences: 12
- Event/global social handle differences: 2

### Contacts

- Event vendors containing local contacts: 40
- Linked contact lists equal: 38
- Local contacts only: 15
- Global contacts only: 7
- Local and global contacts both present but different: 7
- Total linked contact mismatches: 29
- Malformed contact entries: 0
- Unknown contact keys: 0

The four contact states account for all 67 linked event vendors.

### ROS vendor values

- ROS items with a meaningful vendor value: 984
- Whitespace-only stored vendor values: 234
- Exact event-scoped matches: 230
- Normalized matches: 0
- Ambiguous matches: 0
- Unmatched values: 754
- Unmatched placeholders: 1
- Suspected multi-vendor strings using strong delimiters: 0
- Derived-calendar items with vendor values: 0

The audit baseline is a rollout reference, not a migration instruction. Re-run the audit after each data-changing phase and record the new counts in this document.

## Phase 1 — Contacts

### Outcome

Every vendor contact is a stable global contact record, and every event vendor explicitly selects the contacts relevant to that event. No contact data is discarded.

### Schema

Add `global_vendor_contacts` with:

- `global_vendor_id` foreign key;
- `name`;
- `title`;
- `email`;
- `phone`;
- `notes`;
- `position`;
- timestamps;
- an index supporting ordered vendor contact lookup.

Add `event_vendor_contacts` with:

- `event_vendor_id` foreign key;
- `global_vendor_contact_id` foreign key;
- `position`;
- timestamps;
- a unique index on `(event_vendor_id, global_vendor_contact_id)`.

Add and enforce the event-vendor structural constraints supported by the production audit:

- unique `(event_id, global_vendor_id)` index;
- non-null `event_vendors.global_vendor_id` after the backfill verifies there are no unlinked rows.

Implement the additive tables, contact backfill, verification checks, unique event/global index, and non-null constraint in one new transactional migration. If any verification fails, the migration must roll back the schema and backfill together. Retain the original JSON columns unchanged for the Phase 4 verification window. Do not expose the contact backfill as a rerunnable production task: after planners change selections, rerunning legacy JSON would incorrectly restore old selections.

### Contact Backfill Rules

For each global vendor:

1. Read the original global contact JSON and local contact JSON from every linked event vendor.
2. Normalize surrounding whitespace and blank values without changing meaningful casing, email content, phone formatting, or notes.
3. Build the global contact directory from the union of every meaningful contact record.
4. Deduplicate only records that are equivalent across all normalized stored fields. Preserve similar-but-different records separately.
5. Create event contact selections from the event vendor's local contact list when it is meaningful.
6. When the event-local list is empty, select the original global contacts for that event vendor.
7. Skip blank contact hashes and preserve all conflicting meaningful records.

These rules automatically handle the audited states:

- Equal lists select the shared contacts.
- Local-only contacts are recovered globally and selected for their event.
- Global-only contacts are selected for their event.
- Differing lists use the event-local list as the initial event selection while retaining the other global contacts as available choices.

### Application Changes

- Add `GlobalVendorContact` and `EventVendorContact` models and associations.
- Validate that an `EventVendorContact` can reference only a contact belonging to its event vendor's global vendor.
- Replace JSON contact editing on the global vendor screen with first-class contact rows.
- Replace the temporary read-only event contact display with contact selection controls.
- Keep event meal notes editable on `EventVendor`.
- Derive linked event vendor name/social display from `GlobalVendor`.
- Keep legacy contact JSON columns during the verification window; stop using them as the active source after backfill.

### Planning Company Addendum

Treat Pineapple Productions as a real vendor without changing the planner-facing team workflow:

- Mark the existing canonical global vendor with the unique system role `planning_company`; runtime identity must use this stable role rather than its name or database ID.
- Create one event-vendor association to the planning company for every existing event and transactionally create it with every future event.
- Keep individual Pineapple planner assignments on `EventTeamMember` and keep `Event#pineapple_team_meals` as the planner-facing meal field.
- Keep the existing special planning block on event settings, but derive its company name and social profile from the canonical global vendor.
- Exclude the underlying planning-company event vendor from generic vendor settings, People vendor cards, and duplicate generated-document rows while retaining it in vendor assignment options and ROS Agent vendor context.
- Protect the required event-vendor link from ordinary update, movement, or deletion.
- Audit the system role and event coverage explicitly after migration.

### Consumers to Convert

- Global vendor index and editor.
- Event vendor settings page.
- Event People directory.
- Generated vendor contact section.
- Generated event overview vendor data.
- Generated segment hashing for vendor contacts and event overview.
- ROS Agent event-vendor context where canonical vendor identity is serialized.

### Verification and Handoff

- Model tests for ownership, ordering, uniqueness, and cross-vendor selection rejection.
- Controller tests for global contact CRUD and event contact selection.
- Backfill tests for equal, local-only, global-only, differing, blank, duplicate, and conflicting contacts.
- View tests for global editing and event selection.
- Generated document and hash regression tests.
- Read-only audit confirms all legacy contact information is represented in the new tables.
- The maintainer runs the Phase 1 migrations when requested.
- Phase 1 is complete only after production backfill verification and normal vendor/contact workflows use the new associations.

Local implementation verification recorded July 9, 2026:

- The maintainer applied `NormalizeVendorContacts` successfully in development.
- The full Rails suite passed with 734 tests and 3,914 assertions.
- RuboCop passed for every Phase 1 Ruby change.
- The expanded local audit reported zero legacy global contacts missing from the directory, zero legacy event contacts missing from the directory, zero expected selections missing, zero cross-global selections, and zero duplicate selection pairs.
- The planning-company addendum migration adopted one canonical global vendor, associated it with all seven local events, and reported zero events missing the planning-company vendor.
- After the planning-company addendum, the full Rails suite passed with 752 tests and 4,004 assertions.
- Production deployment, production migration, and production audit verification remain required before Phase 1 is marked complete.

## Phase 2 — ROS Transition

### Outcome

ROS items use many-to-many event-vendor associations. Unresolved legacy strings remain visible and filterable without accepting new free-text vendor assignments.

### Schema

Add `calendar_item_event_vendors` with:

- `calendar_item_id` foreign key;
- `event_vendor_id` foreign key;
- `position`;
- timestamps;
- a unique index on `(calendar_item_id, event_vendor_id)`;
- supporting indexes for event-vendor usage lookup.

Application validation and write services must ensure the calendar item and event vendor belong to the same event.

Keep `calendar_items.vendor_name` throughout Phases 2 and 3.

### Automatic Backfill

1. Convert the 234 whitespace-only stored values to `NULL`.
2. Match each meaningful legacy value only against that item's event-vendor roster.
3. Accept a match only when one event vendor matches an exact stored event-vendor name or exact linked global-vendor name.
4. Create the association without replacing any existing association.
5. Clear the legacy string only after the association is successfully persisted.
6. Leave normalized-only, ambiguous, placeholder, multi-vendor, and unmatched values untouched.
7. Make the backfill idempotent and report created associations, cleared blanks, resolved strings, and remaining strings.

The production baseline predicts 230 automatic matches, 234 blank cleanups, and 754 unresolved values.

### ROS Editing Experience

- Replace the normal free-text vendor editor with a searchable multi-select of event vendors.
- Render associated vendors as canonical chips or labels.
- Render remaining legacy text as a distinct “Needs vendor reconciliation” value.
- Make legacy text read-only except for an explicit clear action.
- Display associated vendor names first and use legacy text only as a temporary fallback when no association exists.
- Require vendors to be added to the event roster before they are selectable on ROS items.

### Filters and Bulk Editing

Add separate filters for:

- assigned vendors;
- legacy vendor values;
- needs vendor reconciliation.

Search must include associated vendor names and legacy vendor text.

Replace string-based bulk vendor actions with:

- **Add vendors** — union selected vendors with existing assignments;
- **Remove vendors** — subtract only selected assignments;
- **Clear all vendors** — remove all vendor associations;
- **Clear legacy vendor text** — mark selected legacy values resolved without changing associations;
- **Add vendors and clear legacy text** — add all chosen vendors and clear the legacy value transactionally.

Bulk selectors accept multiple event-vendor IDs and reject IDs outside the current event.

### Consumers to Convert

- ROS item create/edit form.
- Calendar grid inline editor.
- Schedule table and shared timeline partials.
- Calendar search and filter helpers.
- Bulk editor controller, service, and confirmation UI.
- Internal decisions index.
- Client calendar and client decision editor.
- Generated timeline and Run of Show sections.
- Generated document segment hashing.
- Calendar item import behavior.
- ROS Agent event context.
- ROS Agent response schema.
- ROS Agent draft builder, preview, validator, and change-plan applier.
- Vendor option/search endpoints and autocomplete controllers.

ROS Agent and client writes must use event-vendor IDs. They cannot create arbitrary vendor names or placeholder vendors.

### Verification and Handoff

- Migration/backfill tests cover exact event name, exact global alias, unmatched, placeholder, blank, already-associated, and cross-event cases.
- Model and service tests cover multiple vendors, ordering, uniqueness, and same-event ownership.
- System tests cover multi-select editing, legacy display, filters, and every bulk action.
- Document, client, import, and ROS Agent regression tests pass under dual-read behavior.
- The maintainer runs the Phase 2 migrations and exact-match backfill when requested.
- Phase 2 is complete only after the transition UI is live and unresolved legacy values remain safely editable through associations.

## Phase 3 — Planner Reconciliation

### Outcome

Planners resolve every meaningful legacy ROS vendor value using the deployed filters, association editor, and bulk actions. No schema change is required during normal reconciliation.

### Planner Workflow

1. Open the “Needs vendor reconciliation” filter.
2. Narrow by a repeated legacy vendor value when useful.
3. Select all ROS items that share the same intended assignment.
4. Add one or more vendors from the event roster.
5. Add a missing company to the global library and event roster through the explicit roster workflow when necessary.
6. Preserve second and third vendors by using additive assignment rather than replacement.
7. Clear the legacy value only after every intended vendor association is present.
8. Review exceptional items individually when the old string is unclear.

### Progress Tracking

- Show the unresolved legacy item count in the ROS interface.
- Re-run `RAILS_ENV=production bin/rails vendors:audit` periodically.
- Record audit checkpoints below.
- Treat placeholders and obsolete text as planner decisions; do not turn them into global vendors automatically.
- Do not start destructive cleanup while any meaningful legacy value remains.

### Reconciliation Audit Log

| Date | Meaningful legacy values | Exact association coverage | Notes |
| --- | ---: | ---: | --- |
| Initial production baseline | 984 | 230 exact matches available | 754 unmatched before Phase 2 |

### Exit Gate

Phase 3 is complete only when:

- meaningful `calendar_items.vendor_name` count is zero;
- whitespace-only count is zero;
- planners confirm associated vendor displays and filters are sufficient;
- no downstream surface depends on legacy text for correct output.

## Phase 4 — Polish & Complete

### Outcome

The transitional paths and duplicate storage are removed. The database and application enforce the final global → event → ROS hierarchy.

### Legacy Removal

- Remove legacy vendor badges, legacy filters, and reconciliation counts.
- Remove fallback reads from `calendar_items.vendor_name`.
- Remove legacy vendor-name strong parameters and JSON/API fields.
- Remove obsolete implicit ROS-to-global linking behavior and endpoints.
- Drop `calendar_items.vendor_name` in a new migration.
- Drop legacy global/event vendor contact JSON columns in a later new migration after contact parity is verified.
- Remove duplicated event-vendor name and social columns after every consumer resolves those values globally.
- Retain event-vendor type, meals, visibility, ordering, and required global link.

### Product Polish

- Refine empty states, error messages, association chips, contact selectors, and bulk confirmation copy.
- Show event-vendor ROS usage counts where they help prevent accidental removal.
- Block event-vendor deletion while associated ROS items exist unless an explicit detach operation is confirmed.
- Support archived global contacts so historical selections remain understandable without offering inactive contacts for new selections.
- Confirm keyboard and screen-reader behavior for contact and vendor multi-select controls.

### Final Verification

- Production vendor audit shows zero unlinked event vendors, duplicate event/global links, malformed contacts, and meaningful legacy vendor strings.
- Database constraints cover required links, unique joins, and foreign keys.
- All global vendor, event vendor, People directory, ROS, bulk, client, generated document, import, and ROS Agent tests pass.
- Full Rails test suite passes.
- RuboCop passes on changed Ruby files.
- Planner smoke test confirms global contact management, event contact selection, multiple ROS vendors, additive bulk assignment, removal, filtering, and document output.
- The maintainer runs final cleanup migrations when requested.

Phase 4 is complete when the legacy columns and UI are removed, the final audit is clean, and production uses associations exclusively.

## Release and Commit Strategy

1. Commit this plan independently before implementation.
2. Implement Phase 1 in reviewable commits, with migrations isolated from UI/consumer changes when practical.
3. Push and merge Phase 1 only after its targeted tests and migration review pass; the maintainer runs the migration at the explicit handoff.
4. Implement and deploy Phase 2 after Phase 1 production verification.
5. Perform Phase 3 through the application without mixing planner content cleanup into schema migrations.
6. Implement Phase 4 only after the Phase 3 exit gate is satisfied.

Each phase must leave the application deployable and must not require later phases to preserve existing production data.
