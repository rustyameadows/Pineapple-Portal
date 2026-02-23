# Summary
- Build a global vendor and venue directory with only two new tables: `global_vendors` and `global_venues`.
- Keep `event_vendors` and `event_venues` as event-specific records; link them to globals via nullable foreign keys.
- Implement search-first selection everywhere users currently type vendor/venue text, with clear "create new" fallback.
- Rank results to strongly prioritize vendors/venues already active on the current event over pure global matches.
- Roll out in phases: schema/backfill first, settings UX next, then calendar/client entry points, with tests at each step.

# Global Vendors and Venues Infrastructure Plan

## Goal
- Move vendor/venue entry from free-text-first to search-first across the app.
- Prefer existing global records, but allow creating new records inline.
- Keep event-specific controls (contacts, client visibility, ordering) on existing event tables.
- Minimize DB expansion and reduce migration risk.

## Current State (Verified)
- Event-scoped records:
  - `event_vendors` (`name`, `vendor_type`, `social_handle`, `contacts_jsonb`, `client_visible`, `position`)
  - `event_venues` (`name`, `contacts_jsonb`, `client_visible`, `position`)
- Primary management UI:
  - `app/views/events/settings/vendors.html.erb`
  - `app/views/events/settings/locations.html.erb`
- Additional free-text vendor/location entry points:
  - `app/views/events/calendar_items/_form.html.erb`
  - `app/views/events/calendar_grids/show.html.erb`
  - `app/views/client/calendars/_decision_modal.html.erb` (vendor only)
  - `app/views/events/settings/_event_details_form.html.erb` (event-level `location`)
- Calendar storage today is string fields:
  - `calendar_items.vendor_name`
  - `calendar_items.location_name`

## Minimal Schema Strategy
- Add exactly two new global tables:
  - `global_vendors`
  - `global_venues`
- Add nullable foreign keys to existing event tables:
  - `event_vendors.global_vendor_id`
  - `event_venues.global_venue_id`
- Keep `event_vendors` and `event_venues` as canonical event membership/config rows.
- Do not add join tables in v1.

## Data Model Design
### `global_vendors`
- Columns:
  - `name` (required)
  - `normalized_name` (required, indexed, unique)
  - optional metadata in v1: `default_vendor_type`, `default_social_handle`
  - timestamps
- Indexes:
  - unique on `normalized_name`
  - btree/trigram index on `name` for search

### `global_venues`
- Columns:
  - `name` (required)
  - `normalized_name` (required, indexed, unique)
  - timestamps
- Indexes:
  - unique on `normalized_name`
  - btree/trigram index on `name` for search

### Existing Event Tables
- `event_vendors`:
  - add `global_vendor_id` FK (nullable initially)
  - keep per-event fields unchanged
- `event_venues`:
  - add `global_venue_id` FK (nullable initially)
  - keep per-event fields unchanged

## Search and Ranking Rules
- Ranking must favor records already active on the current event.
- Proposed score components (vendor and venue pickers):
  - exact match boost
  - prefix match boost
  - substring/fuzzy match boost
  - strong `event_active_boost` when global record is linked to current event
  - global usage boost (number of event links)
  - optional recency boost (recently used on this event)
  - deterministic tiebreak: alphabetical by name
- Result shape should include:
  - `id`, `name`, `is_active_on_event`, `usage_count`, `matched_by`, `score`

## Backend Changes
### New Models
- `app/models/global_vendor.rb`
- `app/models/global_venue.rb`
- Associations:
  - `GlobalVendor has_many :event_vendors`
  - `GlobalVenue has_many :event_venues`
  - `EventVendor belongs_to :global_vendor, optional: true`
  - `EventVenue belongs_to :global_venue, optional: true`

### Services
- `Vendors::OptionSearch` and `Venues::OptionSearch`
  - Encapsulate query + scoring + ordering.
- `Vendors::LinkOrCreate` and `Venues::LinkOrCreate`
  - Given free text or selected global ID:
    - reuse existing event row when already linked
    - otherwise create event row linked to global
    - create global record when no match selected

### Controllers / Routes
- Add event-scoped option endpoints:
  - `GET /events/:event_id/vendor_options`
  - `GET /events/:event_id/venue_options`
- Add JSON response actions (new controllers in `Events::` namespace).
- Update create/update in:
  - `app/controllers/events/event_vendors_controller.rb`
  - `app/controllers/events/event_venues_controller.rb`
- Permit params for selected global IDs and link behavior flags.

## UI/UX Changes
### 1) Settings: Vendors
- File: `app/views/events/settings/vendors.html.erb`
- Replace plain name input with search-first combobox:
  - type to search global list
  - top section: “Already in this event”
  - second section: “Global matches”
  - last action: “Create new vendor: <typed name>”
- On selection:
  - create/link event vendor row
  - keep editing of event-specific fields (type, social, contacts, visibility)

### 2) Settings: Locations
- File: `app/views/events/settings/locations.html.erb`
- Same search-first pattern with event-active weighting and create-new fallback.

### 3) Calendar Item Full Form
- File: `app/views/events/calendar_items/_form.html.erb`
- Convert `vendor_name` and `location_name` inputs to searchable suggestion inputs.
- Selection still writes display text into existing string columns in v1.

### 4) Calendar Grid Inline Editing
- File: `app/views/events/calendar_grids/show.html.erb`
- Add lightweight datalist/autocomplete backed by option endpoints.
- Keep current inline editing speed; do not require modal.

### 5) Client Decision Modal
- File: `app/views/client/calendars/_decision_modal.html.erb`
- Add vendor suggestions API usage (readable list + keyboard navigation).
- Preserve existing permission and payload shape.

### 6) Event Details Location
- File: `app/views/events/settings/_event_details_form.html.erb`
- Add venue suggestions for `event.location`.
- Keep `location_secondary` unchanged.

## Migration and Backfill Plan
1. Create `global_vendors` and `global_venues`.
2. Add nullable FK columns on `event_vendors` and `event_venues`.
3. Backfill globals from existing event rows:
   - normalize names (trim, collapse spaces, lowercase key)
   - one global row per normalized name
4. Backfill event row foreign keys to matched globals.
5. Add indexes after backfill completion.
6. Keep columns nullable for safe rollout; enforce stricter constraints later if needed.

## Deduplication Rules
- Canonicalization function:
  - trim
  - collapse internal whitespace
  - downcase
- Conflict policy:
  - keep earliest created global as canonical
  - map all matching event rows to canonical global
- Preserve original display casing in `name`.

## Test Plan
- Model tests:
  - normalization, uniqueness, associations
- Service tests:
  - ranking order includes event-active boost
  - link vs create behavior
  - dedupe-safe matching
- Controller tests:
  - options endpoints response ordering and payload
  - vendor/venue create/update with global selection
- System/integration tests:
  - settings screens search-select-create flow
  - calendar form/grid suggestion usage
  - no regression for existing edit/delete/reorder operations

## Rollout Plan
1. Ship schema + models + backfill task.
2. Ship settings screens search-first UX (highest value path).
3. Ship calendar form/grid suggestions.
4. Ship client modal vendor suggestions.
5. Observe usage and duplicate-creation rate.
6. Optional v2: migrate calendar item strings to FK-backed references.

## Risks and Mitigations
- Risk: accidental duplicate globals from similar names.
  - Mitigation: strict normalization + exact normalized uniqueness.
- Risk: slower search query at scale.
  - Mitigation: indexed normalized/name fields + capped result set.
- Risk: UX friction if search creates too many near-duplicates.
  - Mitigation: explicit “already on this event” group at top + confirm create-new action.

## Estimated File Touch List (Implementation)
- Models:
  - `app/models/global_vendor.rb`
  - `app/models/global_venue.rb`
  - `app/models/event_vendor.rb`
  - `app/models/event_venue.rb`
- Controllers:
  - `app/controllers/events/event_vendors_controller.rb`
  - `app/controllers/events/event_venues_controller.rb`
  - new option controllers under `app/controllers/events/`
- Views:
  - `app/views/events/settings/vendors.html.erb`
  - `app/views/events/settings/locations.html.erb`
  - `app/views/events/calendar_items/_form.html.erb`
  - `app/views/events/calendar_grids/show.html.erb`
  - `app/views/client/calendars/_decision_modal.html.erb`
  - `app/views/events/settings/_event_details_form.html.erb`
- JS (new or updated Stimulus/controller scripts for combobox behavior)
- Routes:
  - `config/routes.rb`
- DB:
  - new migrations for global tables + FK columns + indexes + backfill
- Tests:
  - controller/model/system tests for all new flows
