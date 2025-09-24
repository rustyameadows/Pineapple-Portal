# Calendar System Implementation Plan

## Phase 1 – Domain Schema & Data Integrity
- Add `event_calendars` table: `event_id` (FK), `name`, `slug`, `description`, `timezone` (defaults to event), `kind` enum (`master`, `derived`), `client_visible` (for planner toggles), `template_source_id` (optional), `position`, and timestamps. Enforce one `master` per event via partial unique index (`event_id`, `kind`) and slug uniqueness per event.
- Create `calendar_items` table keyed to `event_calendars` with fields: `title`, `notes`, `duration_minutes`, `starts_at` (nullable for relative items), `relative_anchor_id` (self FK), `relative_offset_minutes` (signed integer), `relative_before` flag, `locked` flag, `position`, `tag_summary` (cached array of tag names for quick filter labels), and timestamps. Add FK with `on_delete: :cascade` for integrity.
- Model tags with `event_calendar_tags` (`event_calendar_id`, `name`, `color_token?`, `position`) and join table `calendar_item_tags` (`calendar_item_id`, `event_calendar_tag_id`). Keep event-specific taxonomy separate; do not polymorph tag ownership to reduce complexity.
- Store derived view definitions in `event_calendar_views`: `event_calendar_id` (points to master), `name`, `slug`, `description`, `tag_filter` (jsonb array of tag IDs), `hide_locked` flag, `client_visible` flag, `position`, and timestamps. Derived calendars never duplicate items; they reference the master via filter metadata.
- Build parallel template tables (`calendar_templates`, `calendar_template_items`, `calendar_template_tags`, `calendar_template_item_tags`, `calendar_template_views`) mirroring schema, including `variable_definitions` jsonb and `version` column for traceability. Ensure template tables record `default_timezone` and `category` (e.g., One-Day, Weekend) for browsing.
- Update `events` to `has_one :run_of_show_calendar` (master scope), `has_many :event_calendars`, `has_many :event_calendar_views`, and `has_many :calendar_items, through: :event_calendars`. Backfill any seed data for new planner experiences.
- note - confirm whether we want multiple derived calendars stored per event by default or keep the table lean until planners add their own.

## Phase 2 – Scheduling Logic & Domain Services
- Implement models (`EventCalendar`, `CalendarItem`, `EventCalendarTag`, `EventCalendarView`) with validations for presence, slug uniqueness, at least one master per event, max duration, and `relative_anchor` cycle detection. Add helpers: `absolute?`, `relative?`, `effective_starts_at`, `tagged_with?(tag_id)`.
- Build `Calendars::CascadeScheduler` service: accepts an anchor item and recomputes dependent `starts_at` values breadth-first. Respect `locked` items (stop propagation), support both after/before offsets, and persist an `applied_at` timestamp for auditing. Wrap updates in transactions.
- Create `Calendars::DependencyGraph` utility to detect infinite loops or orphaned relatives, raising descriptive errors surfaced in the UI. Add model callback to validate no circular references before save.
- Provide command objects for bulk operations: `ShiftAbsoluteTimes` (move a subset by X minutes), `ReorderItems`, and `DuplicateBranch`. Ensure commands publish analytics/log events for traceability.
- Cache derived view queries via scopes (`EventCalendar.master`, `.derived`, `CalendarItem.by_tag`, `CalendarItem.upcoming`) and preloading strategies to support portal performance.

## Phase 3 – Planner Experience
- Add routes/controllers: `Events::CalendarsController` (show master, manage derived views) and `Events::CalendarItemsController` (CRUD, reorder, lock/unlock). Use Turbo Frames for inline editing and modal forms for new/duplicate items.
- Design run-of-show view in planner layout: chronological list grouped by day/time with inline controls to toggle absolute/relative, choose anchor item (searchable select), set offset (`+/- minutes` inputs), duration, tags, and lock status. Highlight validation errors inline.
- Surface schedule health indicators: badges for items missing anchors, warning banner when cascade blocked by locked relative, and quick filter chips by tag. Provide bulk actions (multi-select checkboxes) for shift and tag assignments.
- Extend derived calendars management UI: form to name view, select tag filters (multi-select), toggle client visibility, preview results live (AJAX filtered list). Include quick links back to portal preview for each view.
- Update event sidebar/navigation to point “Calendars” link to the run-of-show page and expose derived view shortcuts where appropriate, replacing placeholder anchors in `event_links` and event dashboard sections.

## Phase 4 – Templates & Instantiation
- Build planner-accessible template index/editor under `/settings/calendars/templates` (or similar) leveraging the same components as event calendars but scoped to template tables.
- Implement `CalendarTemplates::Instantiate` service: duplicates template data into an event, creates master calendar + derived views, maps template item IDs to new item IDs to preserve relative anchors, applies event timezone, prompts for variables (e.g., {ceremony_duration}) with sensible defaults, and runs cascade scheduler once anchors resolve.
- Add “Save as Template” flow from an event calendar: prompts for template metadata, clones items/tags/views, captures current offsets/durations, and stores version + `template_source_id` on the event calendar.
- Support template versioning by storing `template_version` on instantiated calendars and providing re-sync warnings if the template evolves independently.

## Phase 5 – Client Portal Delivery
- Expand `Client::DecisionCalendarsController` to load master calendar and any views flagged `client_visible`. Provide tab or dropdown navigation to switch between the “Run of Show” and derived views.
- Render client-facing timeline using shared partials: display absolute times, relative descriptions when times unresolved, tag badges, planner notes, and lock indicators (“Finalized”). Offer export links (print-friendly HTML now, ICS later as follow-up).
- Update portal event show page “Useful Event Links” to include new calendar links and ensure the top nav logo already points to event home (existing behavior). Honor team visibility by restricting management actions to planners/admins only.

## Phase 6 – Authorization, UX Polish, & Navigation
- Reuse existing auth helpers to gate planner endpoints (`before_action :require_planner!`). Limit template editing to admins/planners; clients remain read-only.
- Add breadcrumbs and contextual help tooltips explaining relative timing, locking, and cascading behavior. Provide undo messaging (flash with “Revert” link that re-runs scheduler with previous snapshot) for mission-critical safety.
- Integrate flash/alert patterns already used in the app for success/error messaging to maintain consistency.

## Phase 7 – Testing, Observability, & Migration Safety
- Write model specs for calendars/items/tags/views covering validations, cascade results, locking behavior, cycle detection, and tag filters. Add service specs for `CascadeScheduler`, instantiation, and bulk commands.
- Add controller/request tests for planner CRUD, derived view creation, template instantiation, and client portal access. Consider system tests for run-of-show editing to validate Turbo flows.
- Seed fixtures with a representative sample: master calendar with ceremony + reception, tags (vendor, day_of, rehearsal), derived views (Day Of, Vendors). Update factories to support templates.
- Implement migration backfills: default timezone from events, ensure existing events get a placeholder run-of-show record, and provide reversible migrations. Benchmark cascade performance with large data sets; add instrumentation logs or notifications on scheduler runs for monitoring.

## Phase 8 – Rollout & Future Enhancements
- Provide a post-deploy data task to generate starter templates (One Day, Weekend, Elaborate) and ensure planners see immediate value.
- Document administrator playbook: how to create templates, manage tags, handle cascade conflicts, and restore from backups if needed.
- Future roadmap: ICS export, availability sync with vendors, automated reminders on upcoming items, mobile-friendly timeline, and collaborative notes per calendar item.
