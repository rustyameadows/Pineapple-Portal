# Event Flow Cleanup Plan

## Problem Snapshot
- Home dashboard still shows user onboarding form instead of the working team's event portfolio.
- Event listings and detail pages mix global template concepts with event-level assets, adding noise.
- User management is tied to the landing page and lacks a dedicated flow once the org is set up.
- There is no obvious entry point for configuring event-specific settings or stubbing future controls.

## Proposed Solution Path

### 1. Modernize the Logged-In Home Dashboard
- Introduce an `archived` indicator on events (recommend boolean `archived_at` or enum-backed `status`) so we can filter the active roster without destroying history.
- Add `Event.active` scope plus controller query to surface all non-archived events ordered by start date, falling back to updated_at when dates are blank.
- Replace the current user list/form with an event card grid. Each card should show name, schedule snippet, location, and call-to-action linking to the event view.
- Preserve the first-user bootstrap (when no accounts exist) by conditionally redirecting to `users#new` before enforcing the new dashboard.

### 2. Link Event Cards to Detail Views
- Build a shared `_event_card` partial so both the dashboard and any future listings stay consistent.
- Ensure the entire card (not just a tiny link) navigates to `event_path(event)` for quicker access; add accessible focus styling.
- Keep secondary actions (e.g., "Settings", "Documents") inside the card footer so users can branch without leaving the dashboard in the future.

### 3. Standalone User Management Flow
- Expand `UsersController` with an authenticated `index` action listing teammates plus a prominent "Add teammate" button that routes to `users#new`.
- Move the new-user form out of `welcome#home`; reuse the existing template in `users/new` and adjust the controller’s error path so validation failures re-render `users/new`.
- Update global navigation (or dashboard sidebar) to link to the people page; show a light onboarding message if the roster is empty.

### 4. Clean Event Detail View
- Remove template badges and the "Available Templates" section from `events#show`; the templates catalog belongs under the global Templates area.
- Keep questionnaire listings focused on the event-specific forms; ensure template-derived questionnaires are still labeled meaningfully (e.g., via subtitle or metadata if needed elsewhere).
- Adjust the controller to stop loading `@templates`, and prune any helper/tests that expected that block.

### 5. Stub Event Settings Pages
- Add a dedicated `Events::SettingsController` (namespaced) with routes such as `/events/:event_id/settings` (GET) and `/.../settings/team`, `/.../settings/notifications` as future placeholders.
- Create minimal views with headings, breadcrumbs back to the event, and TODO callouts describing upcoming controls.
- Link to the settings landing page from both the event show header and the event cards so product can prototype settings in isolation.

## View Flow Step-Throughs

**Dashboard → Event Details**
- User signs in → redirected to new dashboard showing active event cards.
- Click an event card → lands on `events#show` without template clutter, can review questionnaires/documents.

**Dashboard → Add Teammate**
- From dashboard/nav click "Team" → arrives at roster list with "Add teammate" button.
- Select add teammate → renders `users#new`, submit form → on success redirected back to roster with confirmation.

**Dashboard → Event Settings Stub**
- From an event card (or event show header) click "Settings" → lands on stub settings page clarifying upcoming configuration areas.
- Breadcrumb provides return path to event show or dashboard.

## Dependencies & Open Questions
- Need confirmation on the archival mechanism; if the data model lacks an archive field today we should add `archived_at:datetime` (preferred) and backfill UI/SCOPES accordingly.
- Clarify whether templates require their own top-level navigation beyond the existing `questionnaire_templates_path`; if yes, coordinate copy changes while removing event-level mentions.

## Deliverables Checklist
- Migration/model updates for event archival scope (or alignment with existing field once confirmed).
- Updated `welcome#home` controller/view plus new event card partial and styles.
- Expanded users controller/views and navigation tweaks.
- Simplified event show template and related controller cleanup.
- New event settings routes, controller, and stub views with linking from dashboard/event pages.
