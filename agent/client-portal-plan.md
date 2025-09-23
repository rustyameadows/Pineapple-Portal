# Client Portal Rollout Plan

## 1. Establish Client-Facing Event Shell
- Create a separate namespace (e.g., `Client::EventsController`) that renders within a simplified layout geared toward external viewers. This shell should include the event title, date range, location, and a planner-managed list of "Quick Links" supplied via event settings.
- Add routing so logged-in users can toggle between internal and client views while we defer authentication/role logic for a later phase. (NOTE - there should be a "Portal" button stub in the current event show view that should redirect to the client portal)
- Ensure the shell exposes navigation entry points for every client-facing module (Decision Calendar, Guest List, Questionnaires, Design & Inspo, Financial Management) even if the destination is a stub.

## 2. Quick Links Management
- Extend event settings to capture a curated list of quick links (label + URL, ordered). These will populate the hero area of the client event page. (NOTE - this should be exposed on the current event view. they are stubbed ATM)
- Provide CRUD UI for planners to add, reorder, and delete quick links, storing them in a new `event_links` table (or serialized JSON if we want to avoid a full table). For long-term flexibility, lean toward a dedicated model with ordering.

## 3. Client Event Dashboard (Landing View)
- Build the main client event view featuring:
  - Hero card: event basics and quick links.
  - Three-up grid cards linking to the five client modules. Initial targets:
    1. **Decision Calendar** – stub page describing upcoming workflow.
    2. **Guest List** – stub page describing future functionality.
    3. **Questionnaires** – list of event questionnaires filtered to those marked client-visible (new flag on questionnaire).
    4. **Design & Inspo** – filtered document list showing assets tagged for the client.
    5. **Financial Management** – payments overview (reuse or adapt existing payments UI).
- Make the layout responsive and visually consistent with the internal UI while preserving a lighter, client-friendly tone.

## 4. Module Stubs & Data Hooks
- **Decision Calendar** and **Guest List**: create placeholder pages with TODO messaging and future data requirements. Link from the dashboard cards.
- **Questionnaires**: introduce a `client_visible` boolean on questionnaires and surface only those sections/questions meant for client review (read-only). Reuse the new sectioned presentation.
- **Design & Inspo**: add tagging or boolean flag on documents to filter the list to items curated for the client.
- **Financial Management**: expose a summary of payment milestones/invoices; initially render static or seed data until payment records exist.

## 5. Layout & Styling Considerations
- Introduce a dedicated client layout (e.g., `app/views/layouts/client.html.erb`) with top navigation focused on the client's needs. (NOTE - make the top nav sticky and fixed)
- Leverage existing design tokens but allow for nuanced styling (lighter palette, inline cards). Document shared components for future reuse.

## 6. Roadmap for Roles & Authentication (Future Work)
- Once planner workflows are confirmed, integrate role-based access to switch between internal and client views.
- Implement shareable links or client login flows that land on the new dashboard without exposing internal routes.
