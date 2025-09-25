# Planner Calendar Grid Plan

## Goals
- Give planners a dense, spreadsheet-like view of calendar items for a single event.
- Support inline edits on key fields (title, start/end times, duration, tags, status, visibility) with keyboard-friendly navigation.
- Enable multi-row bulk actions (mass visibility toggles, tag assignments, lock/unlock) without leaving the view.
- Reuse existing authorization, filtering, and validation logic to avoid duplicate rules.

## Current State Summary
- `Client::CalendarsController` already loads calendars for the portal. Planner-side calendars live under `Events::CalendarsController` (to confirm) but currently focus on timeline/presentation views.
- `Calendars::ViewFilter` and associated helpers format run-of-show data; we can tap into similar query logic for planners, but the new grid should operate on raw `CalendarItem` records.
- Existing Stimulus controllers cover light interactions (drag/drop elsewhere), but no dense grid component exists yet—this feature introduces a purpose-built controller without timeline dragging.

## Feature Outline
1. **Route & Controller**
   - Add a planner-only route: `GET /events/:event_id/calendars/:calendar_id/grid` (or similar) → `Events::CalendarsController#grid` (or a dedicated `Events::CalendarGridsController#index`).
   - Link into the existing run-of-show and derived calendar views with an “Edit as Sheet” button plus a return-to-calendar link.
   - Gate with existing planner auth; fetch the event and the specific `EventCalendar` (master or derived) to scope records.
   - Provide JSON endpoints for inline updates and bulk actions: `PATCH /events/:event_id/calendars/:calendar_id/grid/:id` and `PATCH /events/:event_id/calendars/:calendar_id/grid/bulk`.

2. **View Layer**
   - Render a dense `<table>` with sticky headers, grouping rows by date.
   - Columns: checkbox (selection), start time, end time/duration, title, tags (multi-select from existing event tags), owner/assignee, status, visibility, lock flag, notes preview.
   - Include a toolbar for filters (calendar selector, tag filter) and bulk actions (lock/unlock, toggle visibility, assign tags).
   - Provide a paired button that returns to the existing calendar view for the same calendar, showing the identical data in its original layout.
   - Use Turbo Frames to scope updates (each row can be a frame for partial refresh on successful save).

3. **Interaction Layer**
   - Start with table-friendly HTML forms wired directly to Rails endpoints so planners can edit and save rows without extra tooling.
   - (Future enhancement) Introduce a `calendar-grid` Stimulus controller for richer keyboard navigation, inline validation, and optimistic updates once the baseline flow proves itself.

4. **Bulk Edit Workflow**
   - Toolbar actions post to bulk endpoint with selected IDs and operation payload (e.g., `{ action: "set_visibility", value: "client" }`).
   - Server applies strong parameters, runs validations per record, and returns a success/error summary. Failure cases highlight affected rows in the grid.

5. **Supporting Services**
   - Introduce a `Calendars::GridPresenter` to format items and cache computed labels (duration, tag strings) for the view.
   - Add a service object for bulk updates (`Calendars::BulkUpdater`) reusing existing status/lock logic and enforcing tag selection from the calendar’s defined options.
   - Build query helpers for filtering (date range, tag, status, visibility) to keep controller thin.

6. **Styling**
   - Extend `app/assets/stylesheets/application.css` with a `calendar-grid` component: sticky header row, zebra striping per day, compact typography, inline form styling, selection state, and toolbar layout.
   - Ensure responsive handling (horizontal scroll with fixed first columns).

7. **Validation & Error Handling**
   - Reuse `CalendarItem` validations and surface errors inline on the grid when saves fail.
   - No additional audit logging beyond existing callbacks.

8. **Tests**
   - Controller tests for grid index, single update, and bulk update.
   - System test covering basic inline edit flow (select row, edit title, save) if feasible.
   - Stimulus unit tests (optional) or request specs verifying JSON error handling.

9. **Rollout Steps**
   - Ship behind a feature flag or planner role check.
   - Provide documentation/snackbar explaining controls the first time planners land on the grid.
   - Monitor for performance; paginate or lazy-load if events have very large calendars.

## Decisions
- Grid access works for any run-of-show or derived calendar via an “Edit as Sheet” button; planners can return to the timeline view with a paired action.
- No extra audit/versioning is required beyond existing model callbacks.
- Tag editing in the grid surfaces the event’s predefined tags for selection; adding new tags happens outside the grid.

## Next Steps
1. Confirm controller namespace (`Events::CalendarsController` vs new controller).
2. Define the exact column set with planners.
3. Prototype the HTML grid and Stimulus editing on sample data.
4. Add endpoints + services, then connect the Stimulus controller for real persistence.
5. QA with real event calendars; adjust keyboard interactions as needed.
