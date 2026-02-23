# Global Library Management Plan

## Summary
- Add app-wide management for global vendors and global venues under Settings.
- Keep event-level vendor/venue pages for editing workflows, while moving source-of-truth data to globals.
- Enforce picker behavior: selecting a global vendor/venue must add/link it to the current event if not already linked.
- Improve trust with explicit usage visibility and duplicate-safe linking.

## Product Goals
1. Give staff a clear place to manage global vendor and venue libraries.
2. Make “search existing before creating new” consistent everywhere.
3. Ensure picker selection always links to the current event automatically.
4. Keep event-specific controls (contacts, visibility, ordering) intact.
5. Avoid accidental duplicates and stale hidden-ID linkage bugs.

## Required Functional Rule
1. If a user chooses a global vendor/venue from a picker, the app must create or reuse the matching `event_vendors` / `event_venues` row for that event immediately (or on form submit in that workflow), not just copy text.
2. If already linked, the UI should reuse the existing event row and avoid duplicates.

## Current Gaps
1. No global library management UI exists under `/settings`.
2. Global records are created implicitly only via event settings flows.
3. Some picker surfaces are suggestion-only and do not establish event linkage.
4. Hidden global-ID fields can become stale when users manually edit names after selecting an option.

## Scope
### In Scope
1. New app-level settings pages for global vendors and global venues.
2. CRUD for global library records.
3. Usage visibility: how many events use each global record and quick links to events.
4. Keep existing event vendor/location pages as active editing surfaces.
5. Picker-linking guarantees for vendor/venue selection in event workflows.
6. Stale hidden-ID prevention.

### Out of Scope (for this phase)
1. Full merge wizard for large-scale duplicate cleanup.
2. Converting calendar item string columns to FK-backed columns.
3. Bulk import pipeline from CSV.

## UX Plan
### A) Account Settings Entry Points
1. Add two cards on `/settings`:
   - Global Vendors
   - Global Venues

### B) Global Vendors Screen
1. List view with:
   - Name
   - Default type
   - Default social
   - Usage count
   - Last updated
2. Search/filter bar.
3. Inline edit drawer/modal or dedicated edit row.
4. Action buttons:
   - Save
   - Delete (guarded if linked)
5. “Linked events” expandable panel.

### C) Global Venues Screen
1. List view with:
   - Name
   - Usage count
   - Last updated
2. Search/filter bar.
3. Edit/delete with link safety.

### D) Picker UX Rule Across App
1. Searching and selecting an option must carry selected global ID.
2. Submit must link selected global to event row (create if missing).
3. Manual text edits after selection must clear hidden global ID.
4. When no match selected, submit should create a new global record and link it.

## Technical Design
### Routes
1. Add:
   - `GET /settings/global_vendors`
   - `PATCH /settings/global_vendors/:id`
   - `DELETE /settings/global_vendors/:id`
   - `GET /settings/global_venues`
   - `PATCH /settings/global_venues/:id`
   - `DELETE /settings/global_venues/:id`

### Controllers
1. `Settings::GlobalVendorsController`
   - `index`, `update`, `destroy`
2. `Settings::GlobalVenuesController`
   - `index`, `update`, `destroy`

### Models/Services
1. Keep uniqueness by normalized name as source constraint.
2. No propagation service in final model because global tables are the only data source.

### Field Ownership (Explicit)
1. Global tables own canonical identity/profile fields:
   - `global_vendors`: `name`, `normalized_name`, `default_vendor_type`, `default_social_handle`, `contacts_jsonb`
   - `global_venues`: `name`, `normalized_name`, `contacts_jsonb`
2. Event tables become association records:
   - `event_vendors`: `event_id`, `global_vendor_id`, plus event-only metadata you explicitly keep (`client_visible`, `position`)
   - `event_venues`: `event_id`, `global_venue_id`, plus event-only metadata you explicitly keep (`client_visible`, `position`)
3. Contacts are global-owned and edited on global library screens.
4. Event rows derive display name (and contact source) from linked global record.
5. Event-level free-text name edits should be treated as global updates or blocked.

### Transition Steps for Event Tables
1. Add/ensure global contact fields:
   - `global_vendors.contacts_jsonb`
   - `global_venues.contacts_jsonb`
2. Run one backfill migration via `bin/rails db:migrate`:
   - For each existing event vendor/venue row, find-or-create global by normalized name.
   - Copy existing data (name/profile/contacts) into the global record.
   - Set `event_vendors.global_vendor_id` / `event_venues.global_venue_id`.
   - Do not delete legacy event columns in this migration.
3. Switch reads to global-first when FK exists.
4. Switch writes on event settings pages to update global-owned fields.
5. Final cleanup migration later:
   - enforce non-null global FK for active rows
   - remove deprecated event-owned copy fields after verification window.

### Picker Linking Contract
1. Event settings vendor/venue create/update:
   - Resolve selected global ID if present.
   - Else create/find global by normalized name.
   - Link current event row via FK.
   - Block duplicate event link for same global.
2. Calendar item picker selection:
   - If selected option has global ID, trigger “ensure event link” endpoint for current event.
   - Then populate text field.
3. Ensure hidden ID reset when typed value diverges from selected option.

### New Lightweight Endpoints
1. `POST /events/:event_id/vendor_links/ensure`
2. `POST /events/:event_id/venue_links/ensure`
3. Behavior:
   - Input global ID (or normalized name fallback)
   - Return linked event row ID and canonical display name
   - Idempotent

## Files Expected to Change
1. `config/routes.rb`
2. `app/controllers/settings_controller.rb`
3. `app/controllers/settings/global_vendors_controller.rb` (new)
4. `app/controllers/settings/global_venues_controller.rb` (new)
5. `app/controllers/events/event_vendors_controller.rb`
6. `app/controllers/events/event_venues_controller.rb`
7. `app/controllers/events/vendor_links_controller.rb` (new)
8. `app/controllers/events/venue_links_controller.rb` (new)
9. `app/views/settings/show.html.erb`
10. `app/views/settings/global_vendors/index.html.erb` (new)
11. `app/views/settings/global_venues/index.html.erb` (new)
12. `app/views/events/settings/vendors.html.erb`
13. `app/views/events/settings/locations.html.erb`
14. `app/views/events/calendar_items/_form.html.erb`
15. `app/javascript/controllers/remote_options_controller.js`
16. `app/javascript/controllers/custom_select_controller.js`
17. `app/models/global_vendor.rb`
18. `app/models/global_venue.rb`
19. `test/controllers/settings/global_vendors_controller_test.rb` (new)
20. `test/controllers/settings/global_venues_controller_test.rb` (new)
21. `test/controllers/events/vendor_links_controller_test.rb` (new)
22. `test/controllers/events/venue_links_controller_test.rb` (new)

## Data Rules
1. Global name remains canonical for linked event rows.
2. Global contacts are canonical and shared across all linked events.
3. Event row visibility/order remain event-owned.
4. No force/propagation behavior in final model because event rows do not own duplicate profile/contact data.

## Testing Plan
1. Picker selection creates/links event row for current event.
2. Selecting already linked global does not duplicate event row.
3. Manual typing clears stale hidden global ID.
4. Creating new name from picker creates global + event link.
5. Global vendor update is reflected immediately in linked event views.
6. Global venue update is reflected immediately in linked event views.
7. Delete blocked when linked rows exist unless explicit unlink flow is added.

## Rollout Steps
1. Ship global settings index pages (read-only + usage visibility).
2. Ship edit actions.
3. Ship ensure-link endpoints for pickers.
4. Wire picker-linking across event vendor/location + calendar item form.
5. Run backfill migration (`bin/rails db:migrate`) to link all existing live event rows.
6. Add regression tests and run full suite.

## Success Criteria
1. Users can manage global vendors/venues centrally in `/settings`.
2. Picking a global option always links it to the active event.
3. Newly added venue/vendor in one event appears in searches for other events.
4. Duplicate creation rate drops and manual text entry frequency decreases.
